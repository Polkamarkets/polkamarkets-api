class UserSerializer < BaseSerializer
  attributes(
    :username,
    :avatar,
    :slug,
    :address,
  )

  def address
    object.wallet_address
  end
end
