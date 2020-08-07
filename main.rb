require "lib/config.rb"
require "lib/print_lib"
require "lib/report"
require "lib/ticker_data"
require "lib/trading_strategies"

#PrintLib.init

# TODO these calculations will be negatively affected if there are missing
# periods in the history of a stock; perhaps I can start by raising an alarm
# if a ticker suffers from this

history_by_ticker = Config.tickers.map do |ticker|
  TickerData.new(ticker).then do |ticker_data|
    ticker_data.load_history

    ticker_data.clamp!(start_date: Config.start_date, end_date: Config.end_date)
    next if ticker_data.days.empty?

    ticker_data.analyse(
      Config.n_lookback_days,
      Config.n_streak_days,
      Config.target_avg_change,
    )

    ticker_data
  end
end.compact

# TODO: which history enhancers to run?
# TickerData contains data-enhancing methods like analyse,
# calculate_avg_gain_horizon, etc. These may or may not be useful,
# depending on which strategies we want to run. I'm not sure how
# to make this more efficient. Ideally, we would only enhance
# the data we need.
# option 1. each trading strategy starts by telling TickerData to
# enhance data. the latter memoizes or similar.
# option 2. we don't bother with this and always run all enhancements
# option 3. we create a parent "scenario runner" concept with 4 stages;
# collect/load (API/cache); enhance (define which enhancements, possibly
# via ENV); run strategies (or strategyY; unsure why more than one per run);
# report

# TODO strategy end
# I'll need to work on a wind-down/Sell or whatever concept for TradingStrategies.
# Essentially, it direct what should be done with any holdings of shares at the end
# of a strategy execution. Example: sell all for cash. Sell all at target. Etc.
# Possibly, strategies should be pipeable, with a date range or day/month/year count.

#Report.parameters
#Report.baseline_performance(history_by_ticker)

#ts1 = TradingStrategies.execute(
#  strategy: :buy_every_panic_and_sell_at_target,
#  history_by_ticker: history_by_ticker,
#  strategy_options: {
#    rest_days: Config.rest_days,
#    sell_gain_target: Config.sell_gain_target,
#  },
#)
#Report::TradingStrategies.print(ts1)

ts2 = TradingStrategies.execute(
  strategy: :buy_every_panic_and_hold,
  history_by_ticker: history_by_ticker,
  strategy_options: {
    rest_days: Config.rest_days,
  },
)
return ts2[:result_aggregate][:total_profit_percent][:avg]
#Report::TradingStrategies.print(ts2)

#ts3 = TradingStrategies.execute(
#  strategy: :buy_every_n_days_and_hold,
#  history_by_ticker: history_by_ticker,
#  strategy_options: {
#    n_days: Config.buy_n_days,
#  },
#)
#Report::TradingStrategies.print(ts3)

#PrintLib.end
