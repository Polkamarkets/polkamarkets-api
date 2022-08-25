class MarketOutcomeSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :market_id,
    :title,
    :shares,
    :price,
    :price_change_24h
  )

  attribute :price_charts, if: :show_price_charts?

  belongs_to :market, serializer: MarketSerializer

  def id
    # returning eth market id in chain, not db market
    object.eth_market_id
  end

  def market_id
    # returning eth outcome id in chain, not db market
    object.market.eth_market_id
  end

  def price_charts
    object.price_charts(simplified: simplified_price_charts?)
  end

  def show_price_charts?
    scope&.dig(:show_price_charts) ||
      simplified_price_charts? && !object.market.resolved?
  end

  def simplified_price_charts?
    !!scope&.dig(:simplified_price_charts)
  end
end
