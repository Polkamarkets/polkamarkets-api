class TournamentMarketSerializer < ActiveModel::Serializer
  attribute :eth_market_id, key: :id
  attributes(
    :title,
    :image_url,
    :slug
  )
end
