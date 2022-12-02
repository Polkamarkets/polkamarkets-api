module Api
  class GroupLeaderboardsController < BaseController
    before_action :find_group_leaderboard, only: %i[show update join]

    def index
      # requiring user param
      raise 'User param is required' if !params[:user]

      user = params[:user].downcase

      # filtering leaderboards by user creator or user in leaderboard
      group_leaderboards = GroupLeaderboard.where("lower(created_by) = '#{user}' OR lower(users::text)::jsonb @> '\"#{user}\"'")

      group_leaderboards_serialized = group_leaderboards.map do |group_leaderboard|
        {
          id: group_leaderboard.id,
          title: group_leaderboard.title,
          slug: group_leaderboard.slug,
          admin: group_leaderboard.created_by.downcase == user,
        }
      end

      render json: group_leaderboards_serialized, status: :ok
    end

    def show
      render json: @group_leaderboard, status: :ok
    end

    def join
      # requiring user param
      raise 'User param is required' if !params[:user]

      # checking if user belongs to leaderboard already
      if @group_leaderboard.users.map(&:downcase).include?(params[:user].downcase)
        render json: { error: 'User already belongs to leaderboard' }, status: :unprocessable_entity
        return
      end

      @group_leaderboard.users << params[:user]

      if @group_leaderboard.save
        render json: @group_leaderboard, status: :ok
      else
        render json: @group_leaderboard.errors, status: :unprocessable_entity
      end
    end

    def create
      @group_leaderboard = GroupLeaderboard.new(group_leaderboard_params)

      if @group_leaderboard.save
        render json: @group_leaderboard, status: :created
      else
        render json: @group_leaderboard.errors, status: :unprocessable_entity
      end
    end

    def update
      if @group_leaderboard.update(group_leaderboard_params)
        render json: @group_leaderboard, status: :ok
      else
        render json: @group_leaderboard.errors, status: :unprocessable_entity
      end
    end

    private

    def group_leaderboard_params
      params.require(:group_leaderboard).permit(:title, :slug, :created_by, :image_hash, users: [])
    end

    def find_group_leaderboard
      @group_leaderboard = GroupLeaderboard.find_by!(slug: params[:id])
    end
  end
end
