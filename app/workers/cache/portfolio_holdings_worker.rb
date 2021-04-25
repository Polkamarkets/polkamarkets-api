class Cache::PortfolioHoldingsWorker
  include Sidekiq::Worker

  def perform(portfolio_id)
    portfolio = Portfolio.find(portfolio_id)
    return if portfolio.blank?

    portfolio.holdings(refresh: true)
  end
end
