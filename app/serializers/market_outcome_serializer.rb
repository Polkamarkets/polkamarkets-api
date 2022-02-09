class MarketOutcomeSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :market_id,
    :title,
    :shares,
    :price,
    :price_charts
  )

  belongs_to :market, serializer: MarketSerializer

  def id
    # returning eth market id in chain, not db market
    object.eth_market_id
  end

  def market_id
    # returning eth outcome id in chain, not db market
    object.market.eth_market_id
  end
end
