class Discord::PublishMarketCreatedWorker
  include Sidekiq::Worker

  def perform(market_id)
    message = Market::MarketToDiscordBotPresenter.build.build_message(market_id: market_id)
    bot = Discord::Bot.build.start
  end
end
