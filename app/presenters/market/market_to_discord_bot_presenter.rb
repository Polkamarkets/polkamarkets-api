class Market::MarketToDiscordBotPresenter
  def self.build
    new(market_repository: Market)
  end

  def initialize(market_repository:)
    @market_repository = market_repository
  end

  def build_message(market_id:)
    market = @market_repository.find(market_id)

    market.title
  end
end