class Cache::PortfolioActionEventsWorker
  include Sidekiq::Worker

  def perform(portfolio_id)
    portfolio = Portfolio.find(portfolio_id)
    return if portfolio.blank?

    portfolio.action_events(refresh: true)
    # forcing holdings chart refresh
    portfolio.holdings_chart(refresh: true)
  end
end
