module Api
  class TournamentGroupsController < BaseController
    def index
      tournament_groups = TournamentGroup.all

      render json: tournament_groups
    end

    def show
      tournament_group = TournamentGroup.friendly.find(params[:id])

      render json: tournament_group
    end
  end
end
