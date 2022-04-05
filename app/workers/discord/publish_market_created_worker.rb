class Discord::PublishMarketCreatedWorker
  include Sidekiq::Worker

  def perform(market_id)
    market = Market.find_by(id: market_id)
    return if market.blank?

    bot = Discord::Bot.new

    message = I18n.t('market.discord.market_created', title: market.title, url: market.polkamarkets_web_url)
    bot.send_message_to_channel(Rails.application.config_for(:discord).channel_id, message)
  end
end
