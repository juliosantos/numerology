require "./api.rb"
require "./cache.rb"

class HistoricalData
  attr_reader :days, :start_date, :end_date, :gains

  class << self
    def get(ticker, start_date=nil, end_date=nil)
      return new(
        Cache.get("historical_data_#{ticker}") {
          API.get_historical_data(ticker)
        },
        start_date,
        end_date,
      )
    end
  end

  def initialize(days=[], start_date, end_date)
    @days = days
    @start_date = start_date
    @end_date = end_date

    filter_dates!
    set_indices
  end

  def calculate_percentage_change(n_lookback_days)
    @days.each do |day|
      next if day["index"] < n_lookback_days

      lookback_day = days[day["index"] - n_lookback_days]
      day["n_day_percentage_change"] = MathLib.percent_difference(
        lookback_day["close"],
        day["close"],
      )
    end
  end

  def tag_panic_buy_days(n_streak_days, n_lookback_days, target_avg_change)
    days.each do |day|
      # skip if we don't have enough data for the calculation
      next if day["index"] < n_streak_days + n_lookback_days

      # FIXME
      # this should be using ticker_data["days"][(day["index"] - N_LOOKBACK_DAYS)..day["index"]-1] below
      # this is a "do we buy today" signal, so with the close price of today being unknown at that moment,
      # there is not any point to include this; leaving it for now to compare results with the spreadsheet
      day["buy"] = true if (MathLib.average(days[(day["index"] - n_streak_days)..day["index"]].map{ |day| day["n_day_percentage_change"] }) < target_avg_change) && (days[(day["index"] - n_streak_days)..day["index"]].each_slice(2).map{|a,b| b.nil? ? true : a["close"] > b["close"]}.uniq == [true])
    end
  end

  def buy_days
    days.select{ |day| day["buy"] }
  end

  def calculate_gain_horizons_for_buy_days(gain_target_percents)
    buy_days.each do |day|
      gain_target_percents.each do |gain_target_percent|
        gain_day = days[day["index"]..-1].find do |future_day|
          MathLib.percent_difference(
            day["close"],
            future_day["close"]
          ) >= gain_target_percent
        end

        day["gains"] ||= {}
        day["gains"][gain_target_percent] = if gain_day
          gain_day["index"] - day["index"]
        else
          Float::INFINITY
        end
      end
    end
  end

  def calculate_average_gain_horizons(gain_target_percents)
    @gains = gain_target_percents.reduce({}) do |memo, gain_target_percent|
      all_gains = buy_days.map{ |day| day.dig("gains", gain_target_percent) }
      averageable_gains = all_gains - [Float::INFINITY]

      memo[gain_target_percent] = {
        "avg_days_to_gain" => if averageable_gains.any?
          MathLib.average(averageable_gains)
        else
          Float::INFINITY
        end,
        "gain_target_percent_reached_count" => averageable_gains.size,
      }
      memo
    end
  end

private

  def set_indices
    @days.each_with_index do |day, index|
      day["index"] = index
    end
  end

  def filter_dates!
    @days.reject! do |day|
      Date.parse(day["date"]) < start_date 
    end if start_date

    @days.reject! do |day|
      Date.parse(day["date"]) > end_date 
    end if end_date
  end
end
