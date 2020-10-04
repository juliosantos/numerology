require "date"
require "json"

require_relative "config"

module SP500
  MEMBERSHIPS = JSON.parse(File.read("data/sp500-2008-01-31-2019-02-27.json"))
    .transform_keys do |date|
      Date.parse(date).strftime(Config.date_format)
    end.freeze

  # NOTE this will return false for the first day
  # the ticker is a member; we wouldn't buy that very day,
  # I'm supposing
  def self.member?(ticker, date)
    if date < MEMBERSHIPS.keys.first
      false
    elsif date >= MEMBERSHIPS.keys.last
      MEMBERSHIPS.values.last.include?(ticker)
    else
      MEMBERSHIPS
        .each_cons(2)
        .find do |(date1, _), (date2, _)|
          date >= date1 && date < date2
        end[0][1].then do |member_tickers_at_date|
          member_tickers_at_date.include?(ticker)
        end
    end
  end
end
