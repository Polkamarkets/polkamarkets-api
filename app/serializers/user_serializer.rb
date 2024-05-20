class UserSerializer < BaseSerializer
  attributes(
    :username,
    :avatar,
    :slug
  )
end
