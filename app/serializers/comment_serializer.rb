class CommentSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :body,
    :timestamp,
    :user,
    :liked,
    :likes
  )

  belongs_to :user, serializer: ::UserSerializer

  def liked
    return false unless current_user

    object.likes.where(user: current_user).exists?
  end

  def likes
    object.likes.count
  end
end
