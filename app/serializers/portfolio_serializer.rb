class PortfolioSerializer < ActiveModel::Serializer
  attributes(
    :address,
    :holdings_value,
    :holdings_chart
  )

  def address
    object.eth_address
  end
end
