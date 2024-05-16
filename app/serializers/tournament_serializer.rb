class TournamentSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :network_id,
    :slug,
    :title,
    :description,
    :token,
    :created_at,
    :image_url,
    :expires_at,
    :users,
    :position,
    :rank_by,
    :rewards,
    :rules,
    :topics,
    :published,
    :comments_enabled
  )

  has_many :markets, serializer: TournamentMarketSerializer, if: :show_markets?

  # TODO remove; legacy
  belongs_to :tournament_group, key: :group, if: :show_tournament_group?
  belongs_to :tournament_group, key: :land, if: :show_tournament_group?

  def show_tournament_group?
    !instance_options[:show_tournaments]
  end

  def show_markets?
    !instance_options[:hide_tournament_markets]
  end
end
