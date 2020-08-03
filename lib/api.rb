require "httparty"

module API
  def self.get_historical_data(ticker)
    HTTParty.get("https://cloud.iexapis.com/v1/stock/#{ticker}/chart/max", query: {
      chartCloseOnly: true,
      chartByDay: true,
      token: ENV["IEXCLOUD_TOKEN"],
    }).parsed_response
  end
end
