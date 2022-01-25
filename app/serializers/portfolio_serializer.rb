class PortfolioSerializer < ActiveModel::Serializer
  attributes(
    :address,
    :network_id,
    :holdings_value,
    :holdings_performance,
    :holdings_chart,
    :open_positions,
    :closed_markets_profit,
    :liquidity_provided,
    :liquidity_fees_earned
  )

  def address
    object.eth_address
  end
end
