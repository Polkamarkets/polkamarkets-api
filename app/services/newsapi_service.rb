class NewsAPIService
  VERSION = 'v2'.freeze
  BASE_URL = "https://newsapi.org/#{VERSION}/".freeze

  def initialize
    @api_key = Rails.application.config_for(:newsapi).api_key
  end
end