class MinifiedMarketSerializer < ActiveModel::Serializer
  attributes(
    :id,
    :network_id,
    :slug,
    :title,
    :description,
    :created_at,
    :expires_at,
    :fee,
    :state,
    :verified,
    :category,
    :subcategory,
    :image_url,
    :liquidity,
    :liquidity_price,
    :volume,
    :shares,
    :question_id,
    :resolved_outcome_id,
    :voided,
    :trading_view_symbol,
    :question,
    :banner_url,
    :users
  )

  has_many :outcomes, class_name: "MarketOutcome", serializer: MinifiedMarketOutcomeSerializer

  def id
    # returning eth market id in chain, not db market
    object.eth_market_id
  end

  # minified serializer with initial market state

  def volume
    0
  end

  def liquidity_price
    1
  end

  def question
    {
      id: object.question_id,
      bond: 0,
      best_answer: "0x0000000000000000000000000000000000000000000000000000000000000000",
      is_finalized: false,
      is_claimed: false,
      finalize_ts: 0
    }
  end
end
