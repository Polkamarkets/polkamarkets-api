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
  end
end