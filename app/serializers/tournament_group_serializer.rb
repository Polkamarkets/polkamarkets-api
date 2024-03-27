class TournamentGroupSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :slug,
    :title,
    :description,
    :token,
    :created_at,
    :position,
    :users,
    :image_url,
    :banner_url,
    :tags,
    :social_urls
  )

  has_many :tournaments, serializer: TournamentSerializer, if: :show_tournaments?

  def show_tournaments?
    !!scope&.dig(:show_tournaments)
  end
end
