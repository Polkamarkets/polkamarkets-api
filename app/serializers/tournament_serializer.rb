class TournamentSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :network_id,
    :slug,
    :title,
    :description,
    :image_url,
    :markets
  )

  def markets
    object.markets.map do |market|
      {
        title: market.title,
        image_url: market.image_url,
        slug: market.slug,
      }
    end
  end
end
