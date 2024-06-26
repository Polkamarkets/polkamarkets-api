class UserOperationSerializer < BaseSerializer
  attributes(
    :network_id,
    :user,
    :user_operation_hash,
    :status,
    :action,
    :transaction_hash,
    :market_id,
    :market_title,
    :market_slug,
    :outcome_id,
    :outcome_title,
    :image_url,
    :shares,
    :value,
    :timestamp,
    :ticker
  )

  def user
    object.user_address
  end

  def market_id
    object.market&.eth_market_id
  end

  def outcome_id
    object.outcome&.eth_market_id
  end
end
