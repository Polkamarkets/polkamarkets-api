class Cache::PortfolioLiquidityFeesWorker
  include Sidekiq::Worker

  def perform(portfolio_id)
    portfolio = Portfolio.find_by(id: portfolio_id)
    return if portfolio.blank?

    portfolio.liquidity_fees_earned(refresh: true)
  end
end
