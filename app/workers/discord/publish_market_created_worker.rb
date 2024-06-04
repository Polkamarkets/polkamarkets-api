class Discord::PublishMarketCreatedWorker
  include Sidekiq::Worker
  include NetworkHelper

  def perform(market_id)
    # ignores job if discord is not configured
    return unless Discord::Bot.configured?

    market = Market.find_by(id: market_id)
    return if market.blank?

    bot = Discord::Bot.new

    message = I18n.t('market.discord.market_created', title: market.title, url: market.public_url, network: network_name(market.network_id))
    bot.send_message_to_channel(Rails.application.config_for(:discord).channel_id, message)
  end
end
