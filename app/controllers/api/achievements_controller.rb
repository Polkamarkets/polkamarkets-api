module Api
  class AchievementsController < BaseController
    def index
      achievements = Achievement.verified

      if params[:network_id]
        achievements = achievements.where(network_id: params[:network_id])
      end

      render json: achievements, status: :ok
    end

    def show
      # finding items by eth id
      achievement = Achievement.find_by!(params[:id], params[:network_id])

      render json: achievement, status: :ok
    end
  end
end
