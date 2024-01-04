module Api
  class TournamentGroupsController < BaseController
    def index
      tournament_groups = TournamentGroup.order(position: :asc).all

      if params[:token].present?
        tournament_groups = tournament_groups.select do |tournament_group|
          tournament_group.tokens.any? { |token| token[:symbol].downcase == params[:token].downcase }
        end
      end

      render json: tournament_groups, scope: { show_tournaments: true }
    end

    def show
      tournament_group = TournamentGroup.friendly.find(params[:id])

      render json: tournament_group, scope: { show_tournaments: true }
    end
  end
end
