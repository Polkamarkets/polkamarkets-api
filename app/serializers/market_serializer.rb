class MarketSerializer < BaseSerializer
  cache expires_in: 1.hours, except: [:liked, :comments, :related_markets]

  attribute :eth_market_id, key: :id
  attributes(
    :network_id,
    :slug,
    :title,
    :description,
    :created_at,
    :expires_at,
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
    :news,
    :votes,
    :users,
    :liked,
    :likes
  )
  attribute :related_markets, if: :show_related_markets?

  has_many :outcomes, class_name: "MarketOutcome", serializer: MarketOutcomeSerializer
  has_many :comments, serializer: CommentSerializer
  has_many :tournaments, serializer: TournamentSerializer, if: :show_tournaments?

  def question
    object.question_data
  end

  def show_related_markets?
    instance_options[:show_related_markets]
  end

  def show_tournaments?
    true
  end

  def related_markets
    object.related_markets.map do |market|
      MarketSerializer.new(market, show_related_markets: false, show_tournaments: false)
    end
  end

  def liked
    return false unless current_user

    object.likes.where(user: current_user).exists?
  end

  def likes
    object.likes.size
  end
end
