class TournamentSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :network_id,
    :slug,
    :title,
    :description,
    :image_url,
    :expires_at,
    :users,
    :position,
    :rank_by,
    :rewards,
    :rules
  )

  has_many :markets, serializer: TournamentMarketSerializer, if: :show_markets?

  # TODO remove; legacy
  belongs_to :tournament_group, key: :group, if: :show_tournament_group?
  belongs_to :tournament_group, key: :land, if: :show_tournament_group?

  def show_tournament_group?
    !scope&.dig(:show_tournaments)
  end

  def show_markets?
    !scope&.dig(:hide_tournament_markets)
  end
end
