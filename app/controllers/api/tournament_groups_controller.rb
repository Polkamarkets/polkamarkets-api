module Api
  class TournamentGroupsController < BaseController
    def index
      tournament_groups = TournamentGroup.order(position: :asc).all

      render json: tournament_groups, scope: { show_tournaments: true }
    end

    def show
      tournament_group = TournamentGroup.friendly.find(params[:id])

      render json: tournament_group, scope: { show_tournaments: true }
    end
  end
end
