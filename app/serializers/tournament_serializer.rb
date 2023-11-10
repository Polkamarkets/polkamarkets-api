class TournamentSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :network_id,
    :slug,
    :title,
    :description,
    :image_url,
    :markets,
    :expires_at,
    :users,
    :position,
    :rank_by
  )

  # TODO remove; legacy
  belongs_to :tournament_group, key: :group, if: :show_tournament_group?
  belongs_to :tournament_group, key: :land, if: :show_tournament_group?

  def markets
    object.markets.map do |market|
      {
        id: market.eth_market_id,
        title: market.title,
        image_url: market.image_url,
        slug: market.slug,
      }
    end
  end

  def show_tournament_group?
    !scope&.dig(:show_tournaments)
  end
end
