module Api
  class LeaderboardsController < BaseController
    def show
      raise "timeframe parameter is required" if params[:timeframe].blank?

      raise "network_id parameter is required" if params[:network_id].blank?

      leaderboards = StatsService.new.get_leaderboard(
        timeframe: params[:timeframe]
      )

      leaderboard = leaderboards[params[:network_id].to_i] || []

      achievements_service = Bepro::AchievementsContractService.new(network_id: params[:network_id])
      if achievements_service.contract_address.present?
        # adding achievements to leaderboard data
        achievement_token_users = achievements_service.get_achievement_token_users

        leaderboard.each do |user|
          achievement_tokens = AchievementToken.where(
            network_id: params[:network_id],
            eth_id: achievement_token_users.select { |token| token[:user] == user[:user] }.map { |token| token[:id] }
          )
          user[:achievements] = achievement_tokens.map { |token| AchievementTokenSerializer.new(token).as_json }
        end
      else
        leaderboard.each do |user|
          user[:achievements] = []
        end
      end

      render json: leaderboard, status: :ok
    end
  end
end
