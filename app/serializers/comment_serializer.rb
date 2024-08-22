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

    current_user.likes.any? { |l| l.likeable_type == 'Comment' && l.likeable_id == object.id }
  end

  def likes
    object.likes_count
  end
end
