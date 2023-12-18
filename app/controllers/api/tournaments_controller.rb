module Api
  class TournamentsController < BaseController
    def index
      tournaments = Tournament.order(tournament_group_id: :asc, position: :asc).all

      if params[:token].present?
        tournaments = tournaments.select do |tournament|
          tournament.tokens.any? { |token| token[:symbol].downcase == params[:token].downcase }
        end
      end

      render json: tournaments
    end

    def show
      tournament = Tournament.friendly.find(params[:id])

      render json: tournament
    end
  end
end
