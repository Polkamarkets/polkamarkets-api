class FeedService
  attr_accessor :address, :market, :network_id, :actions, :markets

  FEED_ACTIONS = [
    'buy',
    'sell',
    'add_liquidity',
    'remove_liquidity',
    'claim_winnings'
  ].freeze

  def initialize(network_id:, address: nil, market_id: nil)
    raise 'cannot initialize FeedService with address + market_id' if address.present? && market_id.present?

    @address = address
    @market = Market.find_by!(eth_market_id: market_id, network_id: network_id) if market_id.present?
    @network_id = network_id
  end

  def actions
    @_actions ||= Rpc::PredictionMarketContractService.new(network_id: network_id)
      .get_action_events(address: address, market_id: market&.eth_market_id)
      .sort_by { |a| -a[:timestamp] }
  end

  def vote_actions
    @_vote_actions ||= Rpc::VotingContractService.new(network_id: network_id)
      .get_voting_events(user: address, item_id: market&.eth_market_id)
      .sort_by { |a| -a[:timestamp] }
  end

  def create_event_actions
    @_create_event_actions ||=
      Rpc::PredictionMarketContractService.new(network_id: network_id).get_events(event_name: 'MarketCreated')
  end

  def markets
    @_markets ||=
      Market
        .where(network_id: network_id, eth_market_id: actions.map { |a| a[:market_id] }.uniq)
        .includes(:outcomes)
  end

  def voting_markets
    @_voting_markets ||=
      Market
        .where(network_id: network_id, eth_market_id: vote_actions.map { |a| a[:item_id] }.uniq)
        .includes(:outcomes)
  end

  def filtered_actions
    actions.select do |action|
      # filtering buy actions that belong to liquidity actions
      FEED_ACTIONS.include?(action[:action]) &&
        (action[:action] != 'buy' || actions.select { |a| a[:tx_id] == action[:tx_id] }.count < 2)
    end
  end

  def actions_users
    # case insensitive search by list of addresses
    @_actions_users ||= User.where('lower(wallet_address) IN (?)', actions.map { |a| a[:address].downcase }.uniq)
  end

  def feed_actions
    (serialized_actions + serialized_vote_actions).sort_by { |a| -a[:timestamp] }
  end

  def market_feed?
    market.present?
  end

  def user_feed?
    !market_feed?
  end

  def serialized_actions
    filtered_actions.map do |action|
      action_market = markets.find { |m| m.eth_market_id == action[:market_id] }
      outcome = action_market.outcomes.find { |o| o.eth_market_id == action[:outcome_id] } if action[:action] == 'buy' || action[:action] == 'sell' || action[:action] == 'claim_winnings'
      # determining if add_liquidity action is a create_market action by tx_id
      if action[:action] == 'add_liquidity' && create_event_actions.any? { |e| e['transactionHash'] == action[:tx_id] }
        action[:action] = 'create_market'
      end

      user = actions_users.find { |u| u.wallet_address.downcase == action[:address].downcase } if market_feed?

      # using user's avatar if it's a market feed
      image_url =
        user&.avatar ||
        (outcome&.image_url&.present? ? outcome.image_url : action_market.image_url)

      {
        user: user&.username || action[:address],
        action: action[:action],
        market_title: action_market.title,
        market_slug: action_market.slug,
        outcome_title: outcome&.title,
        image_url: image_url,
        shares: action[:shares],
        value: action[:value],
        timestamp: action[:timestamp],
        ticker: action_market.token[:symbol]
      }
    end
  end

  def serialized_vote_actions
    vote_actions.map do |action|
      market = voting_markets.find { |m| m.eth_market_id == action[:item_id].to_i }

      {
        user: action[:user],
        action: action[:action],
        market_title: market.title,
        market_slug: market.slug,
        outcome_title: nil,
        image_url: market.image_url,
        shares: nil,
        value: nil,
        timestamp: action[:timestamp],
        ticker: market.token[:symbol]
      }
    end
  end
end
