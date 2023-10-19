class MarketSerializer < ActiveModel::Serializer
  # cache expires_in: 24.hours

  attributes(
    :id,
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
    :resolution_source,
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
    :users
  )

  has_many :outcomes, class_name: "MarketOutcome", serializer: MarketOutcomeSerializer
  has_many :comments, serializer: CommentSerializer

  def id
    # returning eth market id in chain, not db market
    object.eth_market_id
  end

  def question
    object.question_data
  end
end
