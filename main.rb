require_relative "lib/config"
require_relative "lib/print_lib"
require_relative "lib/report"
require_relative "lib/ticker_data"
require_relative "lib/trading_strategies"

# TODO I'm not considering stock splits or whatever the opposite is called

PrintLib.init

# TODO these calculations will be negatively affected if there are missing
# periods in the history of a stock; perhaps I can start by raising an alarm
# if a ticker suffers from this

def qualified_tickers
  @qualified_tickers ||= begin
    qualified_sectors = [
      "Electronic Technology",
      "Technology Services",
      "Health Technology",
      "Communications",
    ]

    qualified_tags = [
      "Computer Communications",
      "Computer Processing Hardware",
      "Data Processing Services",
      "Electronic Components",
      "Electronic Equipment/Instruments",
      "Electronic Production Equipment",
      "Electronic Technology",
      "Health Technology",
      "Information Technology Services",
      "Internet Retail",
      "Internet Software/Services",
      "Packaged Software",
      "Specialty Telecommunications",
      "Technology Services",
      "Telecommunications Equipment",
    ]

    Dir["./cache/company_info_*"].map do |filename|
      filename.match(/company_info_(.*)/)[1]
    end.select do |ticker|
      company_info = Cache.get("company_info_#{ticker}")

      company_info["issueType"] == "cs" &&
        (qualified_sectors.include?(company_info["sector"]) || (qualified_tags & company_info["tags"]).any?)
    end
  end
end

def fred_nulio_tickers
  %w[AAPL AMZN BABA CRM FB GOOGL GRPN KYAK NFLX PYPL SHOP SNAP SPOT SQ TSLA TWLO UBER ZNGA]
end

def load_and_clamp_history
  tickers = fred_nulio_tickers
  # tickers = qualified_tickers
  @history_by_ticker = tickers.map do |ticker|
    TickerData.new(ticker).then do |ticker_data|
      ticker_data.load_history

      ticker_data.clamp!(start_date: Config.start_date, end_date: Config.end_date)

      # TODO even though no calcs or reporting will
      # be done when `next` triggers, it's still
      # somewheat weird that this doesn't explode
      # with "broken" tickers in .env; maybe raise?
      next if ticker_data.days.size < 10

      ticker_data
    end
  end.compact
end

def clear_panics
  @history_by_ticker.each do |ticker_data|
    ticker_data.days.each { |day| day.delete("panic") }
  end
end

def analyse_history(n_lookback_days, n_streak_days, target_avg_change)
  @history_by_ticker.each do |ticker_data|
    ticker_data.analyse(
      n_lookback_days,
      n_streak_days,
      target_avg_change,
    )
    ticker_data.check_sp500_presence
  end
end

load_and_clamp_history

def run_many
  n_streak_days = 1
  rest_days = 0
  (ARGV[0].to_i..ARGV[1].to_i).to_a.product((-30..-1).to_a)
    .each do |(n_lookback_days, target_avg_change)|
      clear_panics
      analyse_history(
        n_lookback_days,
        n_streak_days,
        target_avg_change,
      )

      ts = TradingStrategies.execute(
        strategy: :buy_every_panic_and_hold,
        history_by_ticker: @history_by_ticker,
        strategy_options: {
          rest_days: rest_days,
          only_sp500: false,
        },
        max_daily: 10_000,
      )

      puts [
        ts[:result_aggregate][:n_buys][:sum],
        ts[:result_aggregate][:cash_spent][:sum],
        n_lookback_days,
        target_avg_change,
        ts[:result_aggregate][:stock_value][:sum].round,
        ts[:result_aggregate][:total_profit_percent][:avg].round,
      ].join("\t")
    end
end
run_many

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

# TODO from the possible panics or buying opportunities,
# incliding automated ones like "buy every n days", I should only do so if the
# company is s&p100 at that time, and I should get a larger dataset but one
# that I can filter, so e.g. "all s&p 500 listings ever from 2000", but prune
# their data for the years they were unliest

def run_one
  clear_panics
  analyse_history(8, 1, -26)

  ts2 = TradingStrategies.execute(
    strategy: :buy_every_panic_and_hold,
    history_by_ticker: @history_by_ticker,
    strategy_options: {
      rest_days: 0,
      only_sp500: false,
    },
    max_daily: 1_000_000,
  )
  Report::TradingStrategies.print(ts2.merge(options: {
    show_trades: true,
    show_individual_results: true,
    show_yearly_trades_chart: true,
  }))
end
# run_one

PrintLib.end
