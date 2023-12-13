class TournamentGroupSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :slug,
    :title,
    :description,
    :position,
    :users,
    :image_url,
    :banner_url
  )

  has_many :tournaments, serializer: TournamentSerializer, if: :show_tournaments?

  def show_tournaments?
    !!scope&.dig(:show_tournaments)
  end
end
