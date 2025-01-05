class UserSerializer < BaseSerializer
  attributes(
    :username,
    :avatar,
    :slug,
    :address,
    :description,
    :website_url,
    :created_at,
    :aliases
  )

  def address
    object.wallet_address
  end
end
