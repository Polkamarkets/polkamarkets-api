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

    object.likes.map(&:user_id).include?(current_user.id)
  end

  def likes
    object.likes.size
  end
end
