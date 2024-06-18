class UserSerializer < BaseSerializer
  attributes(
    :username,
    :avatar,
    :slug,
    :address,
    :description,
    :website_url,
  )

  def address
    object.wallet_address
  end
end
