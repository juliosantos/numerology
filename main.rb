require "bundler/inline"

gemfile do
  source "https://rubygems.org"

  gem "httparty"
  gem "dotenv"
  gem "json"
  gem "pry"
  gem "actionview"
end

require "dotenv"
require "json"
require "pry"
require "action_view"

require "./config.rb"
require "./math_lib.rb"
require "./print_lib.rb"
require "./historical_data.rb"
require "./report.rb"
require "./trading_strategies.rb"

GAIN_TARGET_PERCENTS=1..200

Report.parameters

@historical_data = Config.tickers.each.reduce({}) do |memo, ticker|
  memo[ticker] = {
    "historical_data" => HistoricalData.get(
      ticker,
      Config.start_date,
      Config.end_date,
    ),
  }
  memo
end

report = Report.new(@historical_data, GAIN_TARGET_PERCENTS)
report.oddities

@historical_data.each_with_index do |(ticker, ticker_data), index|
  puts "#{ticker} (#{index}/#{@historical_data.size})"

  ticker_data["historical_data"].calculate_percentage_change(Config.n_lookback_days)

  ticker_data["historical_data"].tag_panic_buy_days(
    Config.n_streak_days,
    Config.n_lookback_days,
    Config.target_avg_change,
  )

  ticker_data["historical_data"].calculate_gain_horizons_for_buy_days(GAIN_TARGET_PERCENTS)

  ticker_data["historical_data"].calculate_average_gain_horizons(GAIN_TARGET_PERCENTS)
end

#Report.new(@historical_data, GAIN_TARGET_PERCENTS).report

report.baseline_performance

TradingStrategies.buy_every_panic_and_sell_at_target(@historical_data)
TradingStrategies.buy_every_n_days_and_hold(@historical_data, 20)
#TradingStrategies.buy_every_panic_and_hold(@historical_data)
