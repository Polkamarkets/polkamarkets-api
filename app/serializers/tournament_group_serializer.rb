class TournamentGroupSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :slug,
    :title,
    :description,
    :position
  )

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

  def group
    object.tournament_group
  end
end
