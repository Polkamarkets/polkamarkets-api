class MarketOutcomeSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :title,
    :price
  )

  has_many :outcomes, class_name: "MarketOutcome", serialize: "MarketOutcomeSerializer"

  def id
    # returning eth market id in chain, not db market
    object.eth_market_id
  end

  def price
    return nil if object.eth_data.blank?

    object.eth_data[:price]
  end
end
