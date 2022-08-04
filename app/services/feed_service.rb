class FeedService
  attr_accessor :user, :network_id, :actions, :markets

  FEED_ACTIONS = [
    'buy',
    'sell',
    'add_liquidity',
    'remove_liquidity',
    'claim_winnings'
  ].freeze

  def initialize(user:, network_id:)
    @user = user
    @network_id = network_id
  end

  def actions
    @actions ||= Bepro::PredictionMarketContractService.new(network_id: network_id)
      .get_action_events(address: user)
      .sort_by { |a| -a[:timestamp] }
  end

  def markets
    @markets ||= Market.where(network_id: network_id, eth_market_id: actions.map { |a| a[:market_id] }.uniq).includes(:outcomes)
  end

  def filtered_actions
    actions.select do |action|
      # filtering buy actions that belong to liquidity actions
      FEED_ACTIONS.include?(action[:action]) &&
        (action[:action] != 'buy' || actions.select { |a| a[:timestamp] == action[:timestamp] }.count < 2)
    end
  end

  def serialized_actions(refresh: false)
    filtered_actions.map do |action|
      market = markets.find { |m| m.eth_market_id == action[:market_id] }
      outcome = market.outcomes.find { |o| o.eth_market_id == action[:outcome_id] } if action[:action] == 'buy' || action[:action] == 'sell'

      {
        user: action[:address],
        action: action[:action],
        market_title: market.title,
        market_slug: market.slug,
        outcome_title: outcome&.title,
        image_url: market.image_url,
        shares: action[:shares],
        value: action[:value],
        timestamp: action[:timestamp]
      }
    end
  end
end
