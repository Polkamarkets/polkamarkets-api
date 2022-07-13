class Discord::PublishMarketExpiringWorker
  include Sidekiq::Worker
  include NetworkHelper

  def perform(market_id)
    # ignores job if discord is not configured
    return unless Discord::Bot.configured?

    market = Market.find_by(id: market_id)
    return if market.blank?

    bot = Discord::Bot.new

    message = I18n.t('market.discord.market_expiring', title: market.title, url: market.polkamarkets_web_url, network: network_name(market.network_id))
    bot.send_message_to_channel(Rails.application.config_for(:discord).channel_id, message)

    # writing to cache
    Rails.cache.write("discord:market_expiring:#{market.network_id}:#{market.eth_market_id}", true, expires_in: 1.week)
  end
end
