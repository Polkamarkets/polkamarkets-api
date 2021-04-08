class MarketSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :title,
    :description,
    :category,
    :subcategory,
    :image_url,
    :liquidity,
    :shares
  )

  has_many :outcomes, class_name: "MarketOutcome", serialize: "MarketOutcomeSerializer"

  def id
    # returning eth market id in chain, not db market
    object.eth_market_id
  end

  def image_url
    # TODO
    'https://localbitcoinnow.com/wp-content/uploads/2019/12/The-bit-logo-e1575819611411.png'
  end

  def volume
    # TODO
    0
  end

  def liquidity
    return nil if object.eth_data.blank?

    object.eth_data[:liquidity]
  end

  def shares
    return nil if object.eth_data.blank?

    object.eth_data[:shares]
  end
end
