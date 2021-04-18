class PortfolioSerializer < ActiveModel::Serializer
  attributes(
    :address,
    :holdings_value,
    :holdings_chart,
    :open_positions,
    :resolved_earnings,
    :liquidity_provided,
    :liquidity_fees_earned
  )

  def address
    object.eth_address
  end
end
