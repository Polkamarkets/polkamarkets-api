class TournamentMarketSerializer < BaseSerializer
  attribute :eth_market_id, key: :id
  attributes(
    :title,
    :image_url,
    :slug
  )
end
