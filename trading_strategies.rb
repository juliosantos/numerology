module TradingStrategies
  def self.buy_every_panic_and_sell_at_target(
      tickers_data,
      rest_days: ,
      sell_gain_target:
  )
    cash_amount = 1000

    tickers_data.reduce({}) do |memo, ticker_data|
      buy_days = stagger_days(ticker_data.panic_days, rest_days: rest_days)

      buy_trades = buy_days.map do |day|
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
        sell_day = ticker_data.days[buy_trade[:day]["index"]..-1].find do |future_day|
          MathLib.percent_difference(
            buy_trade[:stock_price],
            future_day["close"],
          ) >= sell_gain_target
        end
        
        {
          ticker: ticker_data.ticker,
          type: "sell",
          day: sell_day,
          date: sell_day["date"],
          stock_price: sell_day["close"],
          stock_amount: buy_trade[:stock_amount],
          cash_earned: buy_trade[:stock_amount] * sell_day["close"],
        } if sell_day
      end.compact

      memo[ticker_data.ticker] = buy_trades + sell_trades
      memo
    end
  end

  def self.buy_every_panic_and_hold(tickers_data, rest_days:)
    cash_amount = 1000

    trades = tickers_data.reduce({}) do |memo, ticker_data|
      buy_days = stagger_days(ticker_data.panic_days, rest_days: rest_days)

      buy_trades = buy_days.map do |day|
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

      memo[ticker_data.ticker] = buy_trades
      memo
    end
  end

  def self.buy_every_n_days_and_hold(tickers_data, n_days:)
    cash_amount = 1000

    tickers_data.reduce({}) do |memo, ticker_data|
      buy_trades = ticker_data.days.each_slice(n_days).map(&:last).map do |day|
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

      memo[ticker_data.ticker] = buy_trades
      memo
    end
  end

  def self.execute(strategy:, tickers_data:, strategy_options:, report_options: {})
    report_options.merge!({
      show_trades: false,
      show_individual_results: false,
    })

    trades_by_ticker = send(strategy, tickers_data, strategy_options)
    result_by_ticker = ticker_result(trades_by_ticker, tickers_data)
    result_aggregate = aggregate_result(result_by_ticker)

    # TODO the next concept is not quite "forecast", but something
    # like "microforecast" or "ending" or "winding down", and it's
    # really about what to do with the shares that we're holding.
    # it could be: nothing; slling them immediately; telling them
    # according to a certain rule (e.g. "at target", according to
    # a calculated expectation of how long it takes to sell at that
    # target, as implemented before; at target or after duration,
    # whichever's shorter;

    report(
      strategy: strategy,
      strategy_options: strategy_options,
      trades_by_ticker: trades_by_ticker,
      result_by_ticker: result_by_ticker,
      result_aggregate: result_aggregate,
      options: report_options,
    ) if report_options.any?
  end

  def self.stagger_days(days, rest_days: 0)
    last_chosen_day = days.first

    days[1..-1].select do |day|
      last_chosen_day =
        day if day["index"] - last_chosen_day["index"] > rest_days
    end
  end

  def self.ticker_result(trades_by_ticker, tickers_data)
    trades_by_ticker.reduce({}) do |memo, (ticker, trades)|
      buy_trades, sell_trades = trades.partition{ |t| t[:type] == :buy }
      n_buys, n_sells = [buy_trades, sell_trades].map(&:size)
      cash_spent = buy_trades.map{ |t| t[:cash_spent] }.sum
      cash_earned = sell_trades.map{ |t| t[:cash_earned] }.sum
      cash_profit = cash_earned - cash_spent
      cash_profit_percent = MathLib.percent_difference(cash_spent, cash_earned)
      stock_held = [buy_trades, sell_trades].map do |ts|
        ts.map{ |t| t[:stock_amount] }.sum
      end.reduce(:-)
      stock_value = stock_held * tickers_data.find do |ticker_data|
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
      memo
    end
  end
  
  def self.aggregate_result(result_by_ticker)
    %i|
      n_buys
      n_sells
      cash_spent
      cash_earned
      cash_profit
      cash_profit_percent
      stock_value
      total_value
      total_profit
      total_profit_percent
    |.reduce({}) do |memo, query|
      memo[query] = result_by_ticker.values.map do |ticker_data|
        ticker_data[query]
      end.then do |all_values|
        {
          sum: all_values.sum,
          avg: MathLib.average(all_values),
        }
      end
      memo
    end
  end

  def self.report_ticker(ticker:, trades:, result:, options: {})
    PrintLib.h2(PrintLib.ticker(ticker))

    if options[:show_trades]
      PrintLib.h3 "Trades"
      
      trades.sort_by{ |t| t[:date] }.each_with_index do |trade, index|
        PrintLib.puts(
         (index + 1).to_s.rjust(trades.size.to_s.size),
          ". ",
          trade[:type].to_s.upcase,
          " ",
          trade[:date],
          " @ ",
          number_with_delimiter(trade[:stock_price]),
        )
      end || PrintLib.puts("(no trades)")
      PrintLib.newline
    end

    PrintLib.h3 "Result"
    PrintLib.puts "Number of buys: ", result[:n_buys]
    PrintLib.puts(
      "Cash spent: ",
      number_with_delimiter(result[:cash_spent].round),
    )
    PrintLib.puts(
      "Cash earned: ",
      number_with_delimiter(result[:cash_earned].round),
    )
    PrintLib.puts(
      "Stock value: ",
      number_with_delimiter(result[:stock_value].round),
    )
    PrintLib.puts(
      "Total value: ",
      number_with_delimiter(result[:total_value].round),
    )
    PrintLib.puts(
      "Total profit: ",
      number_with_delimiter(result[:total_profit].round),
      " (",
      number_with_delimiter(result[:total_profit_percent].round),
      "%)",
    )
    PrintLib.newline
  end

  def self.report(
      strategy:,
      strategy_options:,
      trades_by_ticker:,
      result_by_ticker:,
      result_aggregate:,
      options: {})
    PrintLib.h1(
      strategy.to_s.gsub("_", " "),
      " (",
      strategy_options.to_a.map do |option|
        option.join(": ")
      end.join(", "),
      ")",
    )

    result_by_ticker.each do |ticker, result|
      report_ticker(
        ticker: ticker,
        trades: trades_by_ticker[ticker],
        result: result_by_ticker[ticker],
        options: options,
      )
    end if options[:show_individual_results]

    PrintLib.h2("Aggregate")
    PrintLib.puts("Number of buys: ", result_aggregate[:n_buys][:sum])
    PrintLib.puts(
      "Cash spent: ",
      number_with_delimiter(result_aggregate[:cash_spent][:sum].round),
    )
    PrintLib.puts(
      "Cash earned: ",
      number_with_delimiter(result_aggregate[:cash_earned][:sum].round),
    )
    PrintLib.puts(
      "Stock value: ",
      number_with_delimiter(result_aggregate[:stock_value][:sum].round),
    )
    PrintLib.puts(
      "Total value: ",
      number_with_delimiter(result_aggregate[:total_value][:sum].round),
    )
    PrintLib.puts(
      "Total profit: ",
      number_with_delimiter(result_aggregate[:total_profit][:sum].round),
      " (",
      number_with_delimiter(result_aggregate[:total_profit_percent][:avg].round),
      "%)",
    )
    PrintLib.newline
  end
end
