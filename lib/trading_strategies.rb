require_relative "core_extensions"
require_relative "math_lib"

module TradingStrategies
  def self.buy_every_panic_and_sell_at_target(
    history_by_ticker,
    rest_days:,
    sell_gain_target:
  )
    cash_amount = 1000

    history_by_ticker.each_with_object({}) do |ticker_data, memo|
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

  def self.buy_every_panic_and_hold(history_by_ticker, rest_days:)
    cash_amount = 1000

    history_by_ticker.each_with_object({}) do |ticker_data, memo|
      memo[ticker_data.ticker] =
        ticker_data.panic_days.stagger(rest_days).map do |day|
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

  def self.buy_every_n_days_and_hold(history_by_ticker, n_days:)
    cash_amount = 1000

    history_by_ticker.each_with_object({}) do |ticker_data, memo|
      memo[ticker_data.ticker] = ticker_data.days.stagger(n_days)
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

  def self.execute(strategy:, history_by_ticker:, strategy_options:)
    trades_by_ticker = send(strategy, history_by_ticker, strategy_options)
    result_by_ticker = ticker_result(trades_by_ticker, history_by_ticker)
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
      stock_value = stock_held * history_by_ticker.find do |ticker_data|
        ticker_data.ticker == ticker
      end.days.last["close"]

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
