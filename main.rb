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
require "./ticker_data.rb"
require "./report.rb"
require "./trading_strategies.rb"

PrintLib.init

Report.parameters

tickers_data = Config.tickers.map do |ticker|
  TickerData.new(ticker).tap do |ticker_data|
    ticker_data.get_historical_data(Config.start_date, Config.end_date)
    ticker_data.analyse(
      Config.n_lookback_days,
      Config.n_streak_days,
      Config.target_avg_change,
      Config.sell_gain_target,
    )
  end
end

report = Report.new(tickers_data)
report.baseline_performance

TradingStrategies.execute(
  strategy: :buy_every_panic_and_sell_at_target,
  tickers_data: tickers_data,
  strategy_options: {
    rest_days: Config.rest_days,
    sell_gain_target: Config.sell_gain_target,
  },
)

TradingStrategies.execute(
  strategy: :buy_every_panic_and_hold,
  tickers_data: tickers_data,
  strategy_options: {
    rest_days: Config.rest_days,
  },
)

TradingStrategies.execute(
  strategy: :buy_every_n_days_and_hold,
  tickers_data: tickers_data,
  strategy_options: {
    n_days: Config.buy_n_days,
  },
)

PrintLib.end
