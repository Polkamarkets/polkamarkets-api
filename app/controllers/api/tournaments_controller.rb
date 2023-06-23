module Api
  class TournamentsController < BaseController
    def index
      tournaments = Tournament.all

      render json: tournaments
    end

    def show
      tournament = Tournament.friendly.find(params[:id])

      render json: tournament
    end

    def create
      tournament = Tournament.new(tournament_params)

      if tournament.save
        render json: tournament, status: :created
      else
        render json: tournament.errors, status: :unprocessable_entity
      end
    end

    def update
      tournament = Tournament.friendly.find(params[:id])

      if tournament.update(tournament_params)
        render json: tournament
      else
        render json: tournament.errors, status: :unprocessable_entity
      end
    end

    def destroy
      tournament = Tournament.friendly.find(params[:id])

      tournament.destroy
    end

    private

    def tournament_params
      params.require(:tournament).permit(:title, :description, :image_url, :network_id, market_ids: [])
    end
  end
end
