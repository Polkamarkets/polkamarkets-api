class TournamentSerializer < BaseSerializer
  cache expires_in: 24.hours

  attributes(
    :id,
    :network_id,
    :slug,
    :title,
    :description,
    :token,
    :created_at,
    :image_url,
    :metadata_url,
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

  belongs_to :tournament_group, key: :land, if: :show_tournament_group?

  def show_tournament_group?
    !instance_options[:show_tournaments]
  end

  def show_markets?
    !instance_options[:hide_tournament_markets]
  end
end
