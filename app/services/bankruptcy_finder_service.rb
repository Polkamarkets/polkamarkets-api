class BankruptcyFinderService
  include NetworkHelper

  attr_accessor :user, :network_id, :actions, :mint_actions, :markets_resolved, :portfolio

  def initialize(user, network_id)
    @user = user
    @network_id = network_id
    @actions = network_actions(network_id)
    @mint_actions = network_mint_actions(network_id)
    @markets_resolved = network_markets_resolved(network_id)
    @portfolio = Portfolio.new(eth_address: user.downcase, network_id: network_id)
  end

  def is_bankrupt?
    bankrupt = false
    needs_rescue = false
    total_minted = 0
    earnings = 0
    market_ids = []

    user_mint_actions.each_with_index do |mint_action, index|
      next_mint_action = user_mint_actions[index + 1]
      total_minted += mint_action[:value]

      actions_to_check = user_actions.select do |action|
        action[:block_number] >= mint_action[:block_number] &&
          (next_mint_action.nil? || action[:block_number] < next_mint_action[:block_number])
      end

      earnings += actions_to_check.select do |action|
        ['sell', 'claim_voided'].include?(action[:action])
      end.sum { |action| action[:value] }

      earnings -= actions_to_check.select do |action|
        ['buy'].include?(action[:action])
      end.sum { |action| action[:value] }

      portfolio = Portfolio.new(eth_address: user.downcase, network_id: network_id)

      market_ids += actions_to_check.map { |action| action[:market_id] }.uniq
      market_ids.uniq!

      resolved_markets_to_check = markets_resolved.map { |action| action[:market_id] }.select do |market_id|
        actions_to_check.any? { |action| action[:market_id] == market_id }
      end

      winnings = portfolio.closed_markets_winnings(
        filter_by_market_ids: resolved_markets_to_check,
      )

      portfolio_value = portfolio.holdings_value(filter_by_market_ids: market_ids)

      earnings += winnings[:value]
      earnings += portfolio_value

      bankrupt_in_timeframe = (total_minted + earnings).abs < 1e-5

      bankrupt ||= bankrupt_in_timeframe
      needs_rescue = bankrupt_in_timeframe
    end

    {
      bankrupt: bankrupt,
      needs_rescue: needs_rescue
    }
  end

  def user_actions
    @_user_actions ||= actions.select { |action| action[:address].downcase == user.downcase }
  end

  def user_mint_actions
    @_user_mint_actions ||= mint_actions.select { |action| action[:to].downcase == user.downcase }
  end

  def user_markets
    @_user_markets ||= Market.where(eth_market_id: user_actions.map { |action| action[:market_id] }.uniq, network_id: network_id)
  end
end
