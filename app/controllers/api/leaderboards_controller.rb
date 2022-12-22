module Api
  class LeaderboardsController < BaseController
    before_action :validate_params, only: [:index, :show]

    def index
      leaderboard = get_leaderboard(params[:network_id])

      render json: leaderboard, status: :ok
    end

    def show
      user_leaderboard = get_user_leaderboard(params[:network_id], params[:id])

      render json: user_leaderboard, status: :ok
    end

    private

    def get_leaderboard(network_id)
      leaderboards = StatsService.new.get_leaderboard(
        timeframe: params[:timeframe]
      )

      leaderboard = leaderboards[network_id.to_i] || []

      achievements_service = Bepro::AchievementsContractService.new(network_id: network_id)
      if achievements_service.contract_address.present?
        # adding achievements to leaderboard data
        achievement_token_users = achievements_service.get_achievement_token_users
        achievement_tokens = AchievementToken
          .includes(:achievement)
          .where(network_id: network_id, eth_id: achievement_token_users.map { |token| token[:id] })

        leaderboard.each do |user|
          achievement_token_ids = achievement_token_users.select { |token| token[:user] == user[:user] }.map { |token| token[:id].to_i }
          user[:achievements] = achievement_tokens
            .select { |token| achievement_token_ids.include?(token.eth_id) }
            .map { |token| AchievementTokenSerializer.new(token).as_json }
        end
      else
        leaderboard.each do |user|
          user[:achievements] = []
        end
      end

      # removing blacklisted users from leaderboard
      leaderboard.reject! { |l| l[:user].in?(Rails.application.config_for(:ethereum).blacklist) }

      leaderboard
    end

    def get_user_leaderboard(network_id, user)
      leaderboard = get_leaderboard(params[:network_id])

      user_leaderboard = leaderboard.find { |l| l[:user].downcase == user.downcase }

      return user_not_found(user) if user_leaderboard.blank?

      # adding the rank per parameter to the user leaderboard
      rank = {
        markets_created: leaderboard.sort_by { |user| -user[:markets_created] }.index(user_leaderboard) + 1,
        volume: leaderboard.sort_by { |user| -user[:volume] }.index(user_leaderboard) + 1,
        tvl_volume: leaderboard.sort_by { |user| -user[:tvl_volume] }.index(user_leaderboard) + 1,
        tvl_liquidity: leaderboard.sort_by { |user| -user[:tvl_liquidity] }.index(user_leaderboard) + 1,
        claim_winnings_count: leaderboard.sort_by { |user| -user[:claim_winnings_count] }.index(user_leaderboard) + 1,
      }

      user_leaderboard[:rank] = rank

      user_leaderboard
    end

    def validate_params
      raise "timeframe parameter is required" if params[:timeframe].blank?
      raise "network_id parameter is required" if params[:network_id].blank?
    end

    def user_not_found(user)
      {
        user: user,
        ens: nil,
        markets_created: 0,
        volume: 0,
        tvl_volume: 0,
        liquidity: 0,
        tvl_liquidity: 0,
        claim_winnings_count: 0,
        transactions: 0,
        achievements: [ ],
        rank: {
          markets_created: 0,
          volume: 0,
          tvl_volume: 0,
          tvl_liquidity: 0,
          claim_winnings_count: 0
        }
      }
    end
  end
end
