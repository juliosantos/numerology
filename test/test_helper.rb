require "date"

module TestHelper
  module TickerData
    def make_days(start_date = "2000-01-01", end_date = "2019-12-31")
      (Date.parse(start_date)..Date.parse(end_date)).map do |parsed_date|
        { "date" => parsed_date.strftime(Config.date_format) }
      end
    end
  end
end
