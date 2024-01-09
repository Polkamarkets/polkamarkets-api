class UserSerializer < ActiveModel::Serializer
  attributes(
    :username,
    :avatar,
    :slug
  )
end
