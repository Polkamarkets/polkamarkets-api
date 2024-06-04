class Discord::PublishArbitrationRequestedWorker
  include Sidekiq::Worker
  include NetworkHelper

  def perform(market_id, max_previous)
    # ignores job if discord is not configured
    return unless Discord::Bot.configured?

    market = Market.find_by(id: market_id)
    return if market.blank?

    cache_key = "discord:market_arbitration:#{market.network_id}:#{market.eth_market_id}:#{max_previous}"

    return if Rails.cache.read(cache_key)

    bot = Discord::Bot.new

    message = I18n.t('market.discord.arbitration_requested', title: market.title, url: market.public_url, network: network_name(market.network_id), max_previous: max_previous)
    bot.send_message_to_channel(Rails.application.config_for(:discord).arbitration_channel_id, message)

    # writing to cache
    Rails.cache.write(cache_key, true)
  end
end
