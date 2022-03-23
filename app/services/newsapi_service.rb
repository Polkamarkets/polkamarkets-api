require 'news-api'
require 'cgi'

class NewsAPIService
  attr_accessor :service

  def initialize
    @service = News.new(Rails.application.config_for(:newsapi).api_key)
  end

  def get_latest_news(category, subcategory)
    latest_news = service.get_everything(q: CGI.escape("#{category} OR #{subcategory}"), 
      language: 'en',
      sortBy: 'relevancy'
      pageSize: 3)
    
    latest_news.articles
  end
end