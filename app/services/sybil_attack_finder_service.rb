class SybilAttackFinderService
  include NetworkHelper

  attr_accessor :user, :network_id, :actions, :burn_actions

  CRITERIA = [
    {
      timeframe: 1.hour,
      count: 2
    },
    {
      timeframe: 1.day,
      count: 3
    },
    {
      timeframe: 1.week,
      count: 4
    }
  ];

  def initialize(user, network_id)
    @user = user
    @network_id = network_id
    @actions = network_actions(network_id)
    @burn_actions = network_burn_actions(network_id).select do |action|
      action[:block_number] >= Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :burn_from_block)
    end
  end

  def is_sybil_attacker?
    is_attacker = false
    timeframes_to_analyze = []
    users_to_analyze = []
    accomplices = []

    user_last_burn_block_number = burn_actions.select { |action| action[:from].downcase == user.downcase }&.last&.dig(:block_number) || 0

    # analyzing all sell actions
    user_actions.select { |action| action[:action] == 'sell' && action[:block_number] > user_last_burn_block_number }.each do |action|
      # fetching last buy action for this market
      last_buy_action = user_actions.select do |user_action|
        user_action[:action] == 'buy' &&
          user_action[:market_id] == action[:market_id] &&
          user_action[:timestamp] < action[:timestamp]
      end.last

      raise "No buy action found for user #{user} in market #{action[:market_id]}" if last_buy_action.nil?

      # only analyzing timeframes that are no longer than 1 week
      next if action[:timestamp] - last_buy_action[:timestamp] > 1.week

      # fetching wallets that performed actions between last buy and current sell
      users = actions.select do |market_action|
        market_action[:timestamp] > last_buy_action[:timestamp] &&
          market_action[:timestamp] < action[:timestamp] &&
          market_action[:market_id] == action[:market_id] &&
          market_action[:action] == 'buy' &&
          market_action[:address] != user
      end.map { |market_action| market_action[:address] }.uniq

      timeframes_to_analyze << {
        market_id: action[:market_id],
        timeframe: {
          start: last_buy_action[:timestamp],
          end: action[:timestamp],
          duration: action[:timestamp] - last_buy_action[:timestamp]
        },
        users: users
      }

      users_to_analyze = (users_to_analyze + users).uniq
    end

    users_to_analyze.each do |user|
      CRITERIA.each do |criteria|
        timeframe_count = timeframes_to_analyze.select do |timeframe|
          timeframe[:users].include?(user) &&
            timeframe[:timeframe][:duration] <= criteria[:timeframe]
        end.count

        if timeframe_count >= criteria[:count]
          accomplices << {
            user: user,
            timeframe_count: timeframe_count,
            timeframe: criteria[:timeframe]
          }
        end
      end
    end

    if accomplices.count > 0
      is_attacker = true
    end

    {
      is_attacker: is_attacker,
      accomplices: accomplices.map { |user| user[:user] }.uniq
    }
  end

  def user_actions
    @_user_actions ||= actions.select { |action| action[:address].downcase == user.downcase }
  end

end
