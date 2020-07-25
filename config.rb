Dotenv.load

class Config
  def self.print_lib_enabled
    ENV["PRINT_LIB_ENABLED"] == "1"
  end

  def self.tickers
    ENV["TICKERS"].split.sort
  end

  def self.start_date
    Date.parse(ENV["START_DATE"])
  end

  def self.end_date
    Date.parse(ENV["END_DATE"])
  end

  def self.n_lookback_days
    ENV["N_LOOKBACK_DAYS"].to_i
  end

  def self.n_streak_days
    ENV["N_STREAK_DAYS"].to_i
  end

  def self.target_avg_change
    ENV["TARGET_AVG_CHANGE"].to_f
  end

  def self.sell_gain_target
    ENV["SELL_GAIN_TARGET"].to_i
  end

  def self.method_missing(*args)
    method = args[0].to_s.upcase
  end
end
