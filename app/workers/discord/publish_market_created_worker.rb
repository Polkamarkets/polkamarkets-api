class Discord::PublishMarketCreatedWorker
  include Sidekiq::Worker

  def perform(market_id)
    bot = Discord::Bot.build
    bot.start

    message = Market::MarketToDiscordBotPresenter.build.build_message(market_id: market_id)
    bot.send_message_to_channel(message: message)
    
    bot.stop
  end
end
