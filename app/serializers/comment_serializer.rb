class CommentSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :body,
    :timestamp,
    :user
  )

  belongs_to :user, serializer: ::UserSerializer
end
