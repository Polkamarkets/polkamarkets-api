class SybilAttackFinderService
  include NetworkHelper

  attr_accessor :user, :network_id, :actions, :burn_actions

  CRITERIA = [
    {
      timeframe: 1.hour,
      count: 2
    },
    {
      timeframe: 2.hour,
      count: 4
    },
  ];

  def calculate_markets_sybil_attackers(network_id, market_ids, refresh: false)
    markets = Market.where(eth_market_id: market_ids, network_id: network_id)

    actions = markets.map(&:action_events).flatten
    users = []

    attackers = []
    actions_by_user = actions.group_by { |action| action[:address] }
    actions_users = actions.map { |action| action[:address] }.uniq

    actions_users.each do |user|
      is_attacker = false
      timeframes_to_analyze = []
      users_to_analyze = []
      accomplices = []

      user_actions = actions_by_user[user]

      # analyzing all sell actions
      user_actions.select { |action| action[:action] == 'sell' }.each do |action|
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
            market_action[:outcome_id] == action[:outcome_id] &&
            market_action[:action] == 'buy' &&
            market_action[:address] != user
        end.map { |market_action| market_action[:address] }.uniq

        timeframes_to_analyze << {
          market_id: action[:market_id],
          timeframe: {
            start: Time.at(last_buy_action[:timestamp]),
            end: Time.at(action[:timestamp]),
            duration: action[:timestamp] - last_buy_action[:timestamp]
          },
          users: users,
          market_id: action[:market_id]
        }

        users_to_analyze = (users_to_analyze + users).uniq
      end

      users_to_analyze.each do |user|
        CRITERIA.each do |criteria|
          matched_timeframes = timeframes_to_analyze.select do |timeframe|
            timeframe[:users].include?(user) &&
              timeframe[:timeframe][:duration] <= criteria[:timeframe]
          end

          if matched_timeframes.count >= criteria[:count]
            accomplices << {
              user: user,
              timeframe_count: matched_timeframes.count,
              timeframe: criteria[:timeframe],
              details: matched_timeframes.map do |timeframe|
                { market_id: timeframe[:market_id], timeframe: timeframe[:timeframe] }
              end
            }
          end
        end
      end

      next unless accomplices.count > 0

      attackers.push(
        {
          user: user,
          accomplices: accomplices.map { |accomplice| accomplice[:user] },
          details: accomplices
        }
      )
    end

    attackers
  end

  def calculate_tournament_sybil_attackers(network_id, tournament_id, refresh: false)
    tournament = Tournament.find_by(eth_tournament_id: tournament_id, network_id: network_id)
    return [] if tournament.blank?

    market_ids = tournament.markets.pluck(:eth_market_id).compact

    calculate_markets_sybil_attackers(network_id, market_ids, refresh: refresh)
  end

  def calculate_tournament_group_sybil_attackers(network_id, tournament_group_id, refresh: false)
    tournament_group = TournamentGroup.find_by(eth_tournament_group_id: tournament_group_id, network_id: network_id)
    return [] if tournament_group.blank?

    market_ids = tournament_group.markets.pluck(:eth_market_id).compact

    calculate_markets_sybil_attackers(network_id, market_ids, refresh: refresh)
  end

  def calculate_network_sybil_attackers(network_id, refresh: false)
    market_ids = Market.where(network_id: network_id).pluck(:eth_market_id).compact

    calculate_markets_sybil_attackers(network_id, market_ids, refresh: refresh)
  end
end
