Dotenv.overload

class Config
  def self.tickers
    ENV["TICKERS"].split.sort
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

  def self.method_missing(*args)
    value = ENV[args[0].to_s.upcase]

    if value.nil?
      super
    elsif value == "TRUE"
      true
    elsif value.match /\d+/
      value.to_i
    elsif value.match /\.?\d+\.?\d+/
      value.to_f
    else
      value
    end
  end
end
