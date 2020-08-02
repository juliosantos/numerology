require "dotenv"

Dotenv.overload

class Config
  def self.tickers
    ENV["TICKERS"].split.uniq.sort
  end

  def self.method_missing(method_name, *args, &block)
    value = ENV[method_name.to_s.upcase]

    if value.nil?
      super
    elsif value.match?(/^true$/i)
      true
    elsif value.match?(/^[+-]?\d+$/)
      value.to_i
    elsif value.match?(/^[+-]?\d*\.?\d+$/)
      value.to_f
    else
      value
    end
  end
end
