require "./api.rb"
require "./cache.rb"

class TickerData
  attr_reader :ticker, :days, :start_date, :end_date, :avg_gain_horizon

  def initialize(ticker)
    @ticker = ticker
  end

  def analyse(
    n_lookback_days,
    n_streak_days,
    target_avg_change,
    sell_gain_target
  )
    calculate_percentage_change(n_lookback_days)
    tag_panic_days(n_lookback_days, n_streak_days, target_avg_change)
    calculate_gain_horizons_for_panic_days(sell_gain_target)
    calculate_avg_gain_horizon
  end

  def get_historical_data(start_date=nil, end_date=nil)
    @days = Cache.get("historical_data_#{ticker}") do
      API.get_historical_data(ticker)
    end.reject do |day|
      Date.parse(day["date"]) < @start_date if @start_date
      Date.parse(day["date"]) > @start_date if @end_date
    end.each_with_index do |day, index|
      day["index"] = index
    end
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

  def tag_panic_days(n_lookback_days, n_streak_days, target_avg_change)
    days.each do |day|
      next if day["index"] < n_streak_days + n_lookback_days

      day["panic"] = true if (MathLib.average(days[(day["index"] - n_streak_days)..day["index"]-1].map{ |day| day["n_day_percentage_change"] }) < target_avg_change) && (days[(day["index"] - n_streak_days)..day["index"]].each_slice(2).map{|a,b| b.nil? ? true : a["close"] > b["close"]}.uniq == [true])
    end
  end

  def panic_days
    days.select{ |day| day["panic"] }
  end

  def calculate_gain_horizons_for_panic_days(sell_gain_target)
    panic_days.each do |panic_day|
      panic_day["gain_horizon_day"] = @days[panic_day["index"]..-1].find do |gain_horizon_day|
        MathLib.percent_difference(
          panic_day["close"],
          gain_horizon_day["close"],
        ) >= sell_gain_target
      end
    end
  end

  # TODO I have 2 options here:
  # 1. Select only the buy days that have a sell day
  # 2. Consider all buy days, but then how do I average?
  def calculate_avg_gain_horizon
    # TODO option 1
    #@avg_gain_horizon = MathLib.average(panic_days.select do |panic_day|
    #  panic_day["gain_horizon_day"]
    #end.map do |panic_day|
    #  Date.parse(panic_day["gain_horizon_day"]["date"]) - Date.parse(panic_day["date"])
    #end)

    # TODO option 2
    # assuming you can always sell, but only in 5 years
    #@avg_gain_horizon = MathLib.average(panic_days.map do |panic_day|
    #  if panic_day["gain_horizon_day"]
    #    Date.parse(panic_day["gain_horizon_day"]["date"]) - Date.parse(panic_day["date"])
    #  else
    #    5 * avg_trading_days_per_year
    #  end
    #end)

    panic_days_with_horizon,
    panic_days_without_horizon = panic_days.partition do |panic_day|
      panic_day["gain_horizon_day"]
    end

    @avg_gain_horizon = {
      "avg_existing_horizon" => MathLib.average(
        panic_days_with_horizon.map do |panic_day|
          [
            panic_day["gain_horizon_day"]["date"],
            panic_day["date"]
          ].map do |date|
            Date.parse(date)
          end.reduce(:-)
        end
      ),
      "percent_with_horizon" => MathLib.percentage(
        panic_days_with_horizon.size,
        panic_days.size,
      ),
    }
  end

  def baseline(avg_days=30)
    @baseline ||= begin
      avg_start_price = MathLib.average(
        days.first(avg_days).map { |day| day["close"] }
      )
      avg_end_price = MathLib.average(
        days.last(avg_days).map { |day| day["close"] }
      )

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
    MathLib.average(Hash[days.group_by do |day|
      day["date"][0..3]
    end.to_a[1..-2]].transform_values(&:count).values)
  end

  def avg_trading_days_per_month
    MathLib.average(Hash[days.group_by do |day|
      day["date"][0..6]
    end.to_a[1..-2]].transform_values(&:count).values)
  end
end
