module TradingStrategies
  # FIXME no longer *every* panic because of the new code to avoid buying sequentially
  def self.buy_every_panic_and_sell_at_target(historical_data, rest_days: Config.rest_days)
    PrintLib.h1 "buy_every_panic_and_sell_at_target"
      
    cash_amount = 1000

    buys = historical_data.reduce({}) do |memo, (ticker, ticker_data)|
      buy_days = ticker_data["historical_data"].buy_days(rest_days: rest_days)

      PrintLib.h2(ticker)

      buys = buy_days.map do |day|
        gain_day = ticker_data["historical_data"].days[day["index"]..-1].find do |future_day|
          MathLib.percent_difference(day["close"], future_day["close"]) >= Config.sell_gain_target
        end

        holding_time = if gain_day
          gain_day["index"] - day["index"]
        else
          nil
        end

        profit_percent = if gain_day
         MathLib.percent_difference(day["close"], gain_day["close"])
        else
          nil
        end

        profit = if gain_day
          cash_amount * profit_percent
        else
          nil
        end

        {
          "day" => day,
          "buy_date" => day["date"],
          "buy_price" => day["close"],
          "sell_date" => gain_day&.fetch("date"),
          "sell_price" => gain_day&.fetch("close"),
          "holding_time" => holding_time,
          "profit_percent" => profit_percent,
        }
      end

      if buys.any?
        buys.each_with_index do |buy, index|
          PrintLib.puts [
            index + 1,
            ". ",
            buy["buy_date"],
            " @ ",
            number_with_delimiter(buy["buy_price"]),
          ].push(([
            " -> ",
            buy["sell_price"],
            " @ ",
            buy["sell_date"],
            " : ",
            buy["profit_percent"]&.round,
            "% in ",
            buy["holding_time"],
            " days (",
            buy["holding_time"] / ticker_data["historical_data"].avg_trading_days_per_month,
            " months)",
          ] if buy["sell_date"])).join
        end
        PrintLib.newline
      end

      n_buys = buys.size
      buys_unsold, buys_sold = buys.partition{ |buy| buy["sell_date"].nil? }

      total_bought = buys.size * cash_amount
      total_sold = buys_sold.map{ |buy| cash_amount + buy["profit_percent"] / 100 * cash_amount }.sum
      stock_price = ticker_data["historical_data"].days.last["close"]
      stock_value = buys_unsold.map{ |buy| cash_amount + MathLib.percent_difference(buy["buy_price"], stock_price) / 100.0 * cash_amount }.sum

      stock_value_forecast = if buys_unsold.any?
        buys_unsold.map{ |buy| cash_amount + Config.sell_gain_target / 100.0 * cash_amount }.sum
      else
        0
      end

      last_sale_forecast = if buys_unsold.any?
        if (avg_days_to_gain = ticker_data["historical_data"].gains[Config.sell_gain_target]["avg_days_to_gain"]) < Float::INFINITY
          Date.parse(buy_days.last&.fetch("date")) +
            avg_days_to_gain -
            Config.end_date
        else
          Float::INFINITY
        end
      else
        Float::INFINITY
      end

      PrintLib.puts "Total bought: ", total_bought.round
      PrintLib.puts "Total sold: ", total_sold.round
      PrintLib.puts "Stock value: ", stock_value.round
      PrintLib.puts(
        "Total profit: ",
        MathLib.percent_difference(total_bought, total_sold).round(1),
        "%"
      )
      PrintLib.newline

      PrintLib.h3 "Sell unsold shares now"
      PrintLib.puts "Stock price: ", stock_price.round
      PrintLib.puts(
        "Total sold: ",
        number_with_delimiter((total_sold + stock_value).round),
      )
      PrintLib.puts(
        "Total profit: ",
        MathLib.percent_difference(total_bought, total_sold + stock_value).round(1),
        "%",
      )
      PrintLib.newline

      PrintLib.h3 "Sell unsold shares at target (in #{last_sale_forecast}* days)"
      PrintLib.puts(
        "Stock price: ",
        number_with_delimiter((stock_price + stock_price * Config.sell_gain_target / 100).round),
        "*",
      )
      PrintLib.puts(
       "Total sold: ",
        number_with_delimiter((total_sold + stock_value_forecast).round),
        "*",
      )
      PrintLib.puts(
        "Total profit: ",
        MathLib.percent_difference(
          total_bought,
          total_sold + stock_value_forecast,
      ).round(1),
      "%*",
      )
      PrintLib.newline

      memo[ticker] = {
        "buys" => buys,
        "total_bought" => total_bought,
        "total_sold" => total_sold,
        "sell_now" => {
          "stock_value"=> stock_value,
          "total_sold" => total_sold + stock_value,
        },
        "sell_at_target" => {
          "stock_value" => stock_value_forecast,
          "total_sold" => total_sold + stock_value_forecast,
        },
      }
      memo
    end


    total_bought = buys.values.map{ |buy| buy["total_bought"] }.sum

    stock_value = buys.values.map{ |buy| buy["sell_now"]["stock_value"] }.sum
    total_sold = buys.values.map{ |buy| buy["total_sold"] }.sum
    stock_value_forecast = buys.values.map{ |buy| buy["sell_at_target"]["stock_value"] }.sum

    last_buy_date = buys.values.map do |buys_data|
      buys_data["buys"].last&.dig("day", "date")
    end.compact.max

    stocks_held_forever = 0
    last_sale_forecast = buys.map do |ticker, buys_data|
      avg_days_to_gain = historical_data[ticker]["historical_data"].gains[Config.sell_gain_target]["avg_days_to_gain"]
      if avg_days_to_gain.finite?
        Date.parse(last_buy_date) +
          avg_days_to_gain -
          Config.end_date
      else
        Float::INFINITY
      end
    end.tap do |dates|
      stocks_held_forever = dates.count(Float::INFINITY)
    end.select do |date|
      date.is_a? Date
    end.max


    PrintLib.h2 "Aggregate"
    PrintLib.puts "Total bought:", total_bought.round
    PrintLib.puts "Stock value: ", stock_value.round
    PrintLib.puts "Total sold: ", total_sold.round
    PrintLib.newline

    PrintLib.h3 "Sell unsold shares now"
    PrintLib.puts "Total sold: ", (total_sold + stock_value).round
    PrintLib.puts(
      "Total profit: ",
      MathLib.percent_difference(total_bought, total_sold + stock_value).round(1),
      "%",
    )
    PrintLib.newline

    PrintLib.h3 "Sell unsold shares at target (in #{last_sale_forecast}* days)"
    PrintLib.puts "Buys never sold: ", stocks_held_forever, indent_count: "+1"
    PrintLib.puts "Total sold: ", (total_sold + stock_value_forecast).round, "*"
    PrintLib.puts(
      "Total profit: ",
      MathLib.percent_difference(total_bought, total_sold + stock_value_forecast).round(1),
      "%*",
    )
    PrintLib.newline

    # XXX row below is assuming "sell now" (true)
    total_profit = MathLib.percent_difference(total_bought, total_sold + (true ? stock_value : stock_value_forecast))
    total_profit
  end

  def self.buy_every_panic_and_hold(historical_data, rest_days: Config.rest_days)
    PrintLib.h1 "buy_every_panic_and_hold"

    cash_amount = 1000

    buys = historical_data.map do |ticker, ticker_data|
      PrintLib.h2 ticker

      buys = ticker_data["historical_data"].buy_days(rest_days: Config.rest_days).map do |day|
        {
          "buy_date" => day["date"],
          "price" => day["close"],
        }
      end

      n_buys = buys.size
      total_bought = buys.size * cash_amount

      stock_price = ticker_data["historical_data"].days.last["close"]
      stock_value = buys.select do |buy|
        buy["sell_date"].nil?
      end.map do |buy|
        cash_amount +
            MathLib.percent_difference(buy["price"], stock_price) /
            100.0 * 
            cash_amount
      end.sum

      total_value = stock_value
      total_profit_percent = MathLib.percent_difference(
        total_bought,
        total_value,
      )

      PrintLib.puts "Number of buys: ", n_buys
      PrintLib.puts "Total bought: ", number_with_delimiter(total_bought.round)
      PrintLib.puts "Stock value: ", number_with_delimiter(stock_value.round)
      PrintLib.puts "Total value: ", number_with_delimiter(total_value.round)
      PrintLib.puts "Total profit: ", total_profit_percent.round(1), "%"
      PrintLib.newline

      {
        "n_buys" => n_buys,
        "total_bought" => total_bought,
        "stock_value" => stock_value,
        "total_value" => total_value,
      }
    end


    total_bought = buys.map{ |buy| buy["total_bought"] }.sum
    total_value = buys.map{ |buy| buy["total_value"] }.sum
    total_profit = MathLib.percent_difference(total_bought, total_value)

    PrintLib.h2("Aggregate")
    PrintLib.puts "Number of buys: ", buys.map{ |buy| buy["n_buys"] }.sum
    PrintLib.puts "Total bought: ", number_with_delimiter(total_bought.round)
    PrintLib.puts(
      "Stock value: ",
      number_with_delimiter(buys.map{ |buy| buy["stock_value"] }.sum.round),
    )
    PrintLib.puts "Total value: ", total_value.round
    PrintLib.puts "Total profit: ", total_profit.round(1), "%"
    PrintLib.newline

    total_profit
  end

  def self.buy_every_n_days_and_hold(historical_data, n_days)
    PrintLib.h1("buy_every_n_days_and_hold (#{n_days})")

    cash_amount = 1000

    buys = historical_data.map do |ticker, ticker_data|
      PrintLib.h2 ticker

      buys = ticker_data["historical_data"].days.each_slice(n_days).map(&:last).map do |day|
        {
          "buy_date" => day["date"],
          "price" => day["close"],
        }
      end

      n_buys = buys.size
      total_bought = buys.size * cash_amount

      stock_price = ticker_data["historical_data"].days.last["close"]
      stock_value = buys.map{ |buy| cash_amount + MathLib.percent_difference(buy["price"], stock_price) / 100.0 * cash_amount }.sum

      total_value = stock_value
      total_profit_percent = MathLib.percent_difference(total_bought, total_value)

      PrintLib.puts "Number of buys: ", n_buys
      PrintLib.puts "Total bought: ", number_with_delimiter(total_bought.round)
      PrintLib.puts "Stock value: ", number_with_delimiter(stock_value.round)
      PrintLib.puts "Total value: ", number_with_delimiter(total_value.round)
      PrintLib.puts "Total profit: ", total_profit_percent.round(1), "%"
      PrintLib.newline

      {
        "n_buys" => n_buys,
        "total_bought" => total_bought,
        "stock_value" => stock_value,
        "total_value" => total_value,
      }
    end

    total_bought = buys.map{ |buy| buy["total_bought"] }.sum
    total_value = buys.map{ |buy| buy["total_value"] }.sum
    total_profit = MathLib.percent_difference(total_bought, total_value)

    PrintLib.h2("Aggregate")
    PrintLib.puts "Number of buys: ", buys.map{ |buy| buy["n_buys"] }.sum
    PrintLib.puts "Total bought: ", number_with_delimiter(total_bought.round)
    PrintLib.puts(
      "Stock value: ",
      number_with_delimiter(buys.map{ |buy| buy["stock_value"] }.sum.round),
    )
    PrintLib.puts "Total value: ", number_with_delimiter(total_value.round)
    PrintLib.puts "Total profit: ", total_profit.round(1), "%"
    PrintLib.newline
    
    total_profit
  end
end
