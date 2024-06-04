class MarketOutcomeSerializer < BaseSerializer
  cache expires_in: 24.hours, except: %i[price_charts]

  attributes(
    :id,
    :market_id,
    :title,
    :shares,
    :price,
    :closing_price,
    :price_change_24h,
    :image_url
  )

  attribute :price_charts, if: :show_price_charts?

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
    instance_options[:show_price_charts] ||
      simplified_price_charts? && !object.market.resolved?
  end

  def simplified_price_charts?
    !!instance_options[:simplified_price_charts]
  end
end
