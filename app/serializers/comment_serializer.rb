class CommentSerializer < BaseSerializer
  cache expires_in: 24.hours, except: %i[liked]

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
