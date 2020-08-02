require_relative "api"
require_relative "cache"
require_relative "config"
require_relative "math_lib"

class TickerData
  attr_reader :ticker
  attr_accessor :days

  DATE_FORMAT = "%Y-%m-%d".freeze

  def initialize(ticker)
    @ticker = ticker
  end

  def analyse(n_lookback_days, n_streak_days, target_avg_change)
    calculate_percentage_change(n_lookback_days)
    tag_panic_days(n_lookback_days, n_streak_days, target_avg_change)
  end

  def load_history
    @days = Cache.get("historical_data_#{ticker}") do
      API.get_historical_data(ticker)
    end
  end

  def clamp!(start_date: nil, end_date: nil)
    @days.select! do |day|
      (start_date.nil? || day["date"] >= start_date) &&
        (end_date.nil? || day["date"] <= end_date)
    end
  end

  def calculate_percentage_change(n_lookback_days)
    @days[n_lookback_days..].each do |day|
      day["#{n_lookback_days}_day_percentage_change"] =
        MathLib.percent_difference(
          @days[@days.index(day) - n_lookback_days]["close"],
          day["close"],
        )
    end
  end

  def avg_streak_change(streak_days, n_lookback_days)
    MathLib.average(
      streak_days.map do |day|
        day["#{n_lookback_days}_day_percentage_change"]
      end,
    )
  end

  def monotonic_decrease?(streak_days)
    MathLib.monotonic_decrease?(streak_days.map { |day| day["close"] })
  end

  def streaks(n_lookback_days, n_streak_days)
    @days[n_lookback_days..].each_cons(n_streak_days + 1)
  end

  def tag_panic_days(n_lookback_days, n_streak_days, target_avg_change)
    streaks(n_lookback_days, n_streak_days).each do |*streak_days, next_day|
      next unless avg_streak_change(streak_days, n_lookback_days) < target_avg_change &&
                  monotonic_decrease?(streak_days)

      next_day["panic"] = true
    end
  end

  def panic_days
    @days.select { |day| day["panic"] }
  end

  def find_gain_day(for_day, sell_gain_target)
    @days[@days.index(for_day)..].find do |future_day|
      MathLib.percent_difference(
        for_day["close"], future_day["close"]
      ) >= sell_gain_target
    end
  end

  def baseline(avg_days = 30)
    [
      MathLib.average(@days.first(avg_days).map { |day| day["close"] }),
      MathLib.average(@days.last(avg_days).map { |day| day["close"] }),
    ].then do |avg_start_price, avg_end_price|
      {
        avg_start_price: avg_start_price,
        avg_end_price: avg_end_price,
        performance: MathLib.percent_difference(
          avg_start_price.to_f,
          avg_end_price.to_f,
        ),
      }
    end
  end

  def avg_trading_days_per_year
    MathLib.average(Hash[@days.group_by do |day|
      day["date"][0..3]
    end.to_a[1..-2]].transform_values(&:count).values)
  end

  def avg_trading_days_per_month
    MathLib.average(Hash[@days.group_by do |day|
      day["date"][0..6]
    end.to_a[1..-2]].transform_values(&:count).values)
  end
end
