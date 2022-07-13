class MarketBannerWorker
  include Sidekiq::Worker

  def perform(market_id)
    # only performing in production
    return unless Rails.env.production?

    market = Market.find(market_id)
    return if market.blank?

    market.update_banner_image
  end
end
