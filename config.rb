Dotenv.overload

binding.pry
class Config
  def self.print_lib_stdout
    ENV["PRINT_LIB_STDOUT"] == "1"
  end

  def self.print_lib_file
    ENV["PRINT_LIB_FILE"] == "1"
  end

  def self.tickers
    ENV["TICKERS"].split.sort
  end

  def self.verbose_tickers
    ENV["VERBOSE_TICKERS"] == "1"
  end

  def self.start_date
    Date.parse ENV["START_DATE"]
  rescue
    nil
  end

  def self.end_date
    Date.parse(ENV["END_DATE"])
  rescue
    nil
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
    method = ENV[args[0].to_s.upcase]
  end
end
