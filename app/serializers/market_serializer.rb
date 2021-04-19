class MarketSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :title,
    :description,
    :expires_at,
    :category,
    :subcategory,
    :image_url,
    :liquidity,
    :volume,
    :shares
  )

  has_many :outcomes, class_name: "MarketOutcome", serialize: "MarketOutcomeSerializer"

  def id
    # returning eth market id in chain, not db market
    object.eth_market_id
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
