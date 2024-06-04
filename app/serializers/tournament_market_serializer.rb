class TournamentMarketSerializer < BaseSerializer
  cache expires_in: 24.hours

  attribute :eth_market_id, key: :id
  attributes(
    :title,
    :image_url,
    :slug
  )
end
