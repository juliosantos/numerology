require "json"
require "pry"
require "action_view"

require "./config"
require "./math_lib"
require "./print_lib"
require "./ticker_data"
require "./report"
require "./trading_strategies"

PrintLib.init

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

Report.parameters
Report.baseline_performance(tickers_data)

ts1 = TradingStrategies.execute(
  strategy: :buy_every_panic_and_sell_at_target,
  tickers_data: tickers_data,
  strategy_options: {
    rest_days: Config.rest_days,
    sell_gain_target: Config.sell_gain_target,
  },
)
Report::TradingStrategies.print(ts1)

ts2 = TradingStrategies.execute(
  strategy: :buy_every_panic_and_hold,
  tickers_data: tickers_data,
  strategy_options: {
    rest_days: Config.rest_days,
  },
)
Report::TradingStrategies.print(ts2)

ts3 = TradingStrategies.execute(
  strategy: :buy_every_n_days_and_hold,
  tickers_data: tickers_data,
  strategy_options: {
    n_days: Config.buy_n_days,
  },
)
Report::TradingStrategies.print(ts3)

PrintLib.end
