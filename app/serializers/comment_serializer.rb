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

    object.like_ids.include?(current_user.id)
  end

  def likes
    object.like_ids.count
  end
end
