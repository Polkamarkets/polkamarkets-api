class Cache::PortfolioActionEventsWorker
  include Sidekiq::Worker

  def perform(portfolio_id)
    portfolio = Portfolio.find(portfolio_id)
    return if portfolio.blank?

    portfolio.action_events(refresh: true)
  end
end
