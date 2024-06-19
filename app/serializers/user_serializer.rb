class UserSerializer < BaseSerializer
  attributes(
    :username,
    :avatar,
    :slug,
    :address,
    :description,
    :website_url,
    :created_at,
  )

  def address
    object.wallet_address
  end
end
