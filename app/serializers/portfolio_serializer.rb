class PortfolioSerializer < BaseSerializer
  attributes(
    :address,
    :network_id,
    :holdings_value,
    :open_positions,
    :won_positions,
    :total_positions,
    :first_position_at,
    :accuracy
  )

  def address
    object.eth_address
  end
end
