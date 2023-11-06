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

  belongs_to :tournament_group, key: :group

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
end
