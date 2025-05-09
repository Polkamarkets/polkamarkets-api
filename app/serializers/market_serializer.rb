class MarketSerializer < BaseSerializer
  cache expires_in: 24.hours, except: [:liked, :related_markets]

  attribute :eth_market_id, key: :id
  attributes(
    :network_id,
    :slug,
    :title,
    :description,
    :created_at,
    :expires_at,
    :scheduled_at,
    :fee,
    :treasury_fee,
    :treasury,
    :state,
    :verified,
    :category,
    :subcategory,
    :topics,
    :resolution_source,
    :resolution_title,
    :token,
    :image_url,
    :liquidity,
    :liquidity_eur,
    :liquidity_price,
    :volume,
    :volume_eur,
    :shares,
    :question_id,
    :resolved_outcome_id,
    :voided,
    :trading_view_symbol,
    :question,
    :banner_url,
    :og_image_url,
    :news,
    :votes,
    :users,
    :liked,
    :likes,
    :comments,
    :featured,
    :featured_at,
    :publish_status,
    :image_ipfs_hash,
    :edit_history,
    :sponsorship,
    # relationships as attributes, due to serializer caching optimizations
    :tournaments
  )
  attribute :related_markets, if: :show_related_markets?

  has_many :outcomes, class_name: "MarketOutcome", serializer: MarketOutcomeSerializer
  # has_many :tournaments, serializer: TournamentSerializer, if: :show_tournaments?

  def question
    object.question_data
  end

  def sponsorship
    return nil if object.sponsorship.blank?

    object.sponsorship
  end

  def show_related_markets?
    instance_options[:show_related_markets]
  end

  def show_tournaments?
    true
  end

  def tournaments
    object.tournaments.map do |tournament|
      TournamentSerializer.new(tournament, hide_tournament_markets: true).as_json
    end
  end

  def related_markets
    object.related_markets.map do |market|
      MarketSerializer.new(market, show_related_markets: false, show_tournaments: false)
    end
  end

  def liked
    return false unless current_user

    current_user.likes.any? { |l| l.likeable_type == 'Market' && l.likeable_id == object.id }
  end

  def likes
    object.likes_count
  end

  def comments
    object.comments_count
  end
end
