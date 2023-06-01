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

  def create_event_actions
    @create_event_actions ||= Bepro::PredictionMarketContractService.new(network_id: network_id).get_events(event_name: 'MarketCreated')
  end

  def markets
    @markets ||= Market.where(network_id: network_id, eth_market_id: actions.map { |a| a[:market_id] }.uniq).includes(:outcomes)
  end

  def filtered_actions
    actions.select do |action|
      # filtering buy actions that belong to liquidity actions
      FEED_ACTIONS.include?(action[:action]) &&
        (action[:action] != 'buy' || actions.select { |a| a[:tx_id] == action[:tx_id] }.count < 2)
    end
  end

  def serialized_actions(refresh: false)
    filtered_actions.map do |action|
      market = markets.find { |m| m.eth_market_id == action[:market_id] }
      outcome = market.outcomes.find { |o| o.eth_market_id == action[:outcome_id] } if action[:action] == 'buy' || action[:action] == 'sell'
      # determining if add_liquidity action is a create_market action by tx_id
      if action[:action] == 'add_liquidity' && create_event_actions.any? { |e| e['transactionHash'] == action[:tx_id] }
        action[:action] = 'create_market'
      end

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
