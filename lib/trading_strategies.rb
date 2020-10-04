require_relative "core_extensions"
require_relative "math_lib"

module TradingStrategies # rubocop:disable Metrics/ModuleLength
  def self.buy_every_panic_and_sell_at_target(
    history_by_ticker,
    rest_days:,
    sell_gain_target:
  )
    cash_amount = 1000

    history_by_ticker.each_with_object({}) do |ticker_data, memo|
      # FIXME omg this is so dumb; I'm staggeting an array of dates
      # regardless of their proximity :facepalm:
      ticker_data
        .panic_days
        .each_with_object([])
        .with_index do |(day, acc), index|
          if index.zero? || (Date.parse(day["date"]) - Date.parse(acc[index - 1])) > rest_days
            acc << Date.parse(day["date"])
          end
        end

      buy_trades = ticker_data.panic_days.stagger(rest_days).map do |day|
        {
          ticker: ticker_data.ticker,
          type: :buy,
          day: day,
          date: day["date"],
          stock_price: day["close"],
          stock_amount: cash_amount.to_f / day["close"],
          cash_spent: cash_amount,
        }
      end

      sell_trades = buy_trades.map do |buy_trade|
        next unless (sell_day = ticker_data.find_gain_day(buy_trade[:day], sell_gain_target))

        {
          ticker: ticker_data.ticker,
          type: :sell,
          day: sell_day,
          date: sell_day["date"],
          stock_price: sell_day["close"],
          stock_amount: buy_trade[:stock_amount],
          cash_earned: buy_trade[:stock_amount] * sell_day["close"],
        }
      end.compact

      memo[ticker_data.ticker] = buy_trades + sell_trades
    end
  end

  # FIXME this staggering is broken, because it doesn't stagger adjacent days, but panic days
  def self.buy_every_panic_and_hold(history_by_ticker, rest_days:, only_sp500:)
    cash_amount = 1000

    history_by_ticker.each_with_object({}) do |ticker_data, memo|
      memo[ticker_data.ticker] =
        ticker_data
          .panic_days
          .stagger(rest_days)
          .select do |day|
            only_sp500 ? day["in_sp500"] : true
          end
          .map do |day|
            {
              ticker: ticker_data.ticker,
              type: :buy,
              day: day,
              date: day["date"],
              stock_price: day["close"],
              stock_amount: cash_amount.to_f / day["close"],
              cash_spent: cash_amount,
            }
          end
    end
  end

  def self.buy_every_n_days_and_hold(history_by_ticker, n_days:, only_sp500:)
    cash_amount = 1000

    history_by_ticker.each_with_object({}) do |ticker_data, memo|
      memo[ticker_data.ticker] =
        ticker_data
          .days
          .stagger(n_days)
          .select do |day|
            only_sp500 ? day["in_sp500"] : true
          end
          .map do |day|
            {
              ticker: ticker_data.ticker,
              type: :buy,
              day: day,
              date: day["date"],
              stock_price: day["close"],
              stock_amount: cash_amount.to_f / day["close"],
              cash_spent: cash_amount,
            }
          end
    end
  end

  def self.execute(strategy:, history_by_ticker:, strategy_options:, max_daily: Float::INFINITY)
    make_budget

    trades_by_ticker = send(strategy, history_by_ticker, strategy_options)

    pruned_trades_by_ticker = prune_trades_to_budget(trades_by_ticker, max_daily)

    result_by_ticker = ticker_result(pruned_trades_by_ticker, history_by_ticker)
    result_aggregate = aggregate_result(result_by_ticker)

    # TODO: the next concept is not quite "forecast", but something
    # like "microforecast" or "ending" or "winding down", and it's
    # really about what to do with the shares that we're holding.
    # it could be: nothing; slling them immediately; telling them
    # according to a certain rule (e.g. "at target", according to
    # a calculated expectation of how long it takes to sell at that
    # target, as implemented before; at target or after duration,
    # whichever's shorter;

    {
      strategy: strategy,
      strategy_options: strategy_options,
      trades_by_ticker: trades_by_ticker,
      result_by_ticker: result_by_ticker,
      result_aggregate: result_aggregate,
    }
  end

  def self.make_budget(monthly_increase: 5_000)
    @spent = 0
    @budget = (Date.parse(Config.start_date)..Date.parse(Config.end_date))
      .group_by { |date| [date.year, date.month] }
      .values
      .map(&:first)
      .product([monthly_increase])
      .to_h
  end

  def self.budget_for(target_date)
    target_date = Date.parse(target_date)

    @budget.reduce(0) do |available_at_date, (date, value)|
      break available_at_date if target_date < date

      available_at_date += value
      available_at_date
    end - @spent
  end

  # FIXME we're giving priority to tickers earlier on the list;
  # I didn't just randomize it because I'm not sure of how to deal with
  # that non-determinism
  def self.prune_trades_to_budget(trades_by_ticker, max_daily)
    # FIXME do these dates need sorting?
    trades_by_ticker.values.flatten.group_by { |d| d[:date] }.each_with_object({}) do |(date, trades), memo|
      next unless (available_budget = budget_for(date).clamp(0, max_daily)).positive?

      trades.each do |trade|
        memo[trade[:ticker]] ||= []
        memo[trade[:ticker]] << trade.merge(
          cash_spent: available_budget / trades.size.to_f,
          stock_amount: available_budget / trades.size.to_f / trade[:stock_price],
        )
      end

      @spent += available_budget
    end
  end

  def self.ticker_result(trades_by_ticker, history_by_ticker)
    trades_by_ticker.each_with_object({}) do |(ticker, trades), memo|
      buy_trades, sell_trades = trades.partition { |t| t[:type] == :buy }

      n_buys, n_sells = [buy_trades, sell_trades].map(&:size)

      cash_spent = buy_trades.sum { |t| t[:cash_spent] }
      cash_earned = sell_trades.sum { |t| t[:cash_earned] }
      cash_profit = cash_earned - cash_spent
      cash_profit_percent = MathLib.percent_difference(cash_spent, cash_earned)

      stock_held = [buy_trades, sell_trades].map do |ts|
        ts.map { |t| t[:stock_amount] }.sum
      end.reduce(:-)
      stock_price, stock_price_date = history_by_ticker.find do |ticker_data|
        ticker_data.ticker == ticker
      end.days.last.then do |day|
        [day["close"], day["date"]]
      end
      stock_value = stock_held * stock_price

      total_value = cash_earned + stock_value
      total_profit = total_value - cash_spent
      total_profit_percent = MathLib.percent_difference(cash_spent, total_value)

      memo[ticker] = {
        n_buys: n_buys,
        n_sells: n_sells,
        cash_spent: cash_spent,
        cash_earned: cash_earned,
        cash_profit: cash_profit,
        cash_profit_percent: cash_profit_percent,
        stock_held: stock_held,
        stock_price: stock_price,
        stock_price_date: stock_price_date,
        stock_value: stock_value,
        total_value: total_value,
        total_profit: total_profit,
        total_profit_percent: total_profit_percent,
      }
    end
  end

  def self.aggregate_result(result_by_ticker)
    %i[
      n_buys
      n_sells
      cash_spent
      cash_earned
      cash_profit
      stock_value
      total_value
      total_profit
    ].each_with_object({}) do |query, memo|
      memo[query] = result_by_ticker.values.map do |ticker_data|
        ticker_data[query]
      end.then do |all_values|
        {
          sum: all_values.sum,
          avg: MathLib.average(all_values),
        }
      end
    end.then do |aggregates|
      aggregates.merge({
        cash_profit_percent: {
          avg: MathLib.percent_difference(
            aggregates[:cash_spent][:sum],
            aggregates[:cash_earned][:sum],
          ),
        },
        total_profit_percent: {
          avg: MathLib.percent_difference(
            aggregates[:cash_spent][:sum],
            aggregates[:cash_earned][:sum] +
              aggregates[:stock_value][:sum],
          ),
        },
      })
    end
  end
end
