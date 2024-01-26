class UserOperationSerializer < ActiveModel::Serializer
  attributes(
    :user,
    :user_operation_hash,
    :status,
    :transaction_hash,
    :market_title,
    :market_slug,
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
end
