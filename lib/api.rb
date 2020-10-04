require "httparty"

module API
  class UnknownTicker < StandardError; end

  def self.get_historical_data(ticker)
    HTTParty.get("https://cloud.iexapis.com/v1/stock/#{ticker}/chart/max", query: {
      chartCloseOnly: true,
      chartByDay: true,
      token: ENV["IEXCLOUD_TOKEN"],
    }).tap do |response|
      raise UnknownTicker if response.code == 404
    end.parsed_response
  end

  def self.get_company_info(ticker)
    HTTParty.get("https://cloud.iexapis.com/v1/stock/#{ticker}/company", query: {
      token: ENV["IEXCLOUD_TOKEN"],
    }).tap do |response|
      raise UnknownTicker if response.code == 404
    end.parsed_response
  end
end
