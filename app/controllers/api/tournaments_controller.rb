module Api
  class TournamentsController < BaseController
    # TODO: add auth to endpoints
    # before_action :authenticate_user!, only: %i[create update destroy move_up move_down]

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

    def create
      create_params = tournament_params.except(:market_ids)

      # converting market_ids to markets
      if !tournament_params[:market_ids].nil?
        create_params[:market_ids] = tournament_params[:market_ids].map do |market_id|
          market = Market.find_by!(eth_market_id: market_id, network_id: tournament_params[:network_id])
          market.id
        end
      end

      tournament = Tournament.new(create_params)

      if tournament.save
        render json: tournament, status: :created
      else
        render json: tournament.errors, status: :unprocessable_entity
      end
    end

    def update
      tournament = Tournament.friendly.find(params[:id])

      update_params = tournament_params.except(:market_ids)

      # converting market_ids to markets
      if !tournament_params[:market_ids].nil?
        update_params[:market_ids] = tournament_params[:market_ids].map do |market_id|
          market = Market.find_by!(eth_market_id: market_id, network_id: tournament_params[:network_id])
          market.id
        end
      end

      if tournament.update(update_params)
        render json: tournament
      else
        render json: tournament.errors, status: :unprocessable_entity
      end
    end

    def destroy
      tournament = Tournament.friendly.find(params[:id])

      tournament.destroy
    end

    def move_up
      tournament = Tournament.friendly.find(params[:id])
      tournament.move_higher

      render json: tournament
    end

    def move_down
      tournament = Tournament.friendly.find(params[:id])
      tournament.move_lower

      render json: tournament
    end

    private

    def tournament_params
      params
        .require(:tournament)
        .permit(
          :id,
          :title,
          :description,
          :image_url,
          :network_id,
          :tournament_group_id,
          :rank_by,
          :rules,
          rewards: [:from, :to, :reward],
          market_ids: []
        )
    end
  end
end
