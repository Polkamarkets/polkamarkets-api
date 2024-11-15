class TournamentSerializer < BaseSerializer
  cache expires_in: 24.hours, except: [:markets]

  attributes(
    :id,
    :network_id,
    :slug,
    :title,
    :description,
    :token,
    :created_at,
    :image_url,
    :avatar_url,
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

  attribute :markets, if: :show_markets?

  belongs_to :tournament_group, key: :land, if: :show_tournament_group?

  def markets
    object.markets.select { |market| market.published? }.map do |market|
      TournamentMarketSerializer.new(market)
    end
  end

  def show_tournament_group?
    !instance_options[:show_tournaments]
  end

  def show_markets?
    !instance_options[:hide_tournament_markets]
  end
end
