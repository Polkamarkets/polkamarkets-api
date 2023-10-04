module Admin
  class TournamentGroupsController < BaseController
    def create
      tournament_group = TournamentGroup.new(tournament_group_params)

      if tournament_group.save
        render json: tournament_group, status: :created
      else
        render json: tournament_group.errors, status: :unprocessable_entity
      end
    end

    def update
      tournament_group = TournamentGroup.friendly.find(params[:id])

      if tournament_group.update(tournament_group_params)
        render json: tournament_group
      else
        render json: tournament_group.errors, status: :unprocessable_entity
      end
    end

    def destroy
      tournament_group = TournamentGroup.friendly.find(params[:id])

      tournament_group.destroy
    end

    private

    def tournament_group_params
      params.require(:tournament_group).permit(:id, :title, :description)
    end
  end
end
