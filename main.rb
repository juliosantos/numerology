require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "httparty"
  gem "dotenv"
  gem "json"
  gem "pry"
end

require "dotenv"
require "json"
require "pry"

require "./math_lib.rb"
require "./historical_data.rb"
require "./report.rb"

Dotenv.load

SHEET_TICKERS = %w|AAL AMZN TSLA NFLX FB XOM BRK.A DDAIF UNH INN CSTM HAL WYNN FSLR|
TECH_TICKERS = %w|AMZN TSLA NFLX FB AAPL TWTR SNAP GOOG|
TICKERS = TECH_TICKERS

START_DATE = nil#Date.parse("2010.01.01")
END_DATE = nil#Date.parse("2020.01.01")

# number of days to look back to calculate price change
N_LOOKBACK_DAYS = 1

# number of days to average price changes over
N_STREAK_DAYS = 3

# buy signal threshold: days in which the average of price changes over the past N_STREAK_DAYS is at least as negative as this will be marked as buy days
TARGET_AVG_CHANGE = -8

GAIN_TARGET_PERCENTS = (1..200).to_a

SELL_GAIN_TARGET=40
CASH_VALUE_PER_INVESTMENT=1000

# load and cache stock data
@historical_data = TICKERS.each_with_index.reduce({}) do |memo, (ticker, index)|
  puts "Loading data: #{ticker} (#{index} / #{TICKERS.size})"

  memo[ticker] = {
    "historical_data" => HistoricalData.get(
      ticker,
      START_DATE,
      END_DATE,
    ),
  }

  memo
end

@historical_data.each_with_index do |(ticker, ticker_data), index|
  puts "Calculating percentage change: #{ticker} (#{index} / #{@historical_data.size})"

  ticker_data["historical_data"].calculate_percentage_change(N_LOOKBACK_DAYS)
end

@historical_data.each_with_index do |(ticker, ticker_data), index|
  puts "Marking buy days: #{ticker} (#{index} / #{@historical_data.size})"

  ticker_data["historical_data"].tag_panic_buy_days(
    N_STREAK_DAYS,
    N_LOOKBACK_DAYS,
    TARGET_AVG_CHANGE,
  )
end

@historical_data.each_with_index do |(ticker, ticker_data), index|
  puts "Calculating daily gains horizons: #{ticker} (#{index} / #{@historical_data.size})"

  ticker_data["historical_data"].calculate_gain_horizons_for_buy_days(GAIN_TARGET_PERCENTS)
end

#Report.new(@historical_data, GAIN_TARGET_PERCENTS).report

def buy(target_rise, cash_amount)
  buys = @historical_data.map do |ticker, ticker_data|
    puts ticker
    puts

    buys = ticker_data["historical_data"].buy_days.map do |day|
      gain_day = ticker_data["historical_data"].days[day["index"]..-1].find do |future_day|
        MathLib.percent_difference(day["close"], future_day["close"]) >= target_rise
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
        "buy_date" => day["date"],
        "price" => day["close"],
        "sell_date" => gain_day&.fetch("date"),
        "holding_time" => holding_time,
        "profit_percent" => profit_percent,
      }
    end

    puts "Buys:"
    puts buys
    puts

    n_buys = buys.size
    total_bought = buys.size * cash_amount
    total_sold = buys.reject{ |buy| buy["sell_date"].nil? }.map{ |buy| cash_amount + buy["profit_percent"] / 100 * cash_amount }.sum

    stock_price = ticker_data["historical_data"].days.last["close"]
    stock_value = buys.select{ |buy| buy["sell_date"].nil? }.map{ |buy| puts "price: #{buy["price"]}"; cash_amount + MathLib.percent_difference(buy["price"], stock_price) / 100.0 * cash_amount }.sum

    total_value = total_sold + stock_value
    total_profit_percent = MathLib.percent_difference(total_bought, total_value)

    puts "Number of buys: #{n_buys}"
    puts "Total bought: #{total_bought.round}"
    puts "Total sold: #{total_sold.round}"
    puts "Stock value: #{stock_value.round}"
    puts
    puts "Total value: #{total_value.round}"
    puts "Total profit: #{total_profit_percent.round(1)}%"
    puts 

    {
      "n_buys" => n_buys,
      "total_bought" => total_bought,
      "total_sold" => total_sold,
      "stock_value" => stock_value,
      "total_value" => total_value,
    }
  end

  total_bought = buys.map{ |buy| buy["total_bought"] }.sum
  total_value = buys.map{ |buy| buy["total_value"] }.sum

  puts
  puts "*****************************************"
  puts "Number of buys: #{buys.map{ |buy| buy["n_buys"] }.sum}"
  puts "Total bought: #{total_bought.round}"
  puts "Total sold: #{buys.map{ |buy| buy["total_sold"] }.sum.round}"
  puts "Stock value: #{buys.map{ |buy| buy["stock_value"] }.sum.round}"
  puts
  puts "Total value: #{total_value.round}"
  puts "Total profit: #{MathLib.percent_difference(total_bought, total_value).round(1)}%"
  puts 
  
end

buy(SELL_GAIN_TARGET, CASH_VALUE_PER_INVESTMENT)
