class Discord::PublishMarketCreatedWorker
  include Sidekiq::Worker

  def perform(market_id)
    bot = Discord::Bot.build.start
    message = Market::MarketToDiscordBotPresenter.build.build_message(market_id: market_id)
    bot.send_message_to_channel(channel_id: Config.discord.channel_id, message: message)
  end
end
