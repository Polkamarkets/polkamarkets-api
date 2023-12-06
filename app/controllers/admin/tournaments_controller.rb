module Admin
  class TournamentsController < BaseController
    def create
      create_params = tournament_params.except(:market_ids)

      # converting market_ids to markets
      create_params[:market_ids] = tournament_params[:market_ids].map do |market_id|
        market = Market.find_by!(eth_market_id: market_id, network_id: tournament_params[:network_id])
        market.id
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
      update_params[:market_ids] = tournament_params[:market_ids].map do |market_id|
        market = Market.find_by!(eth_market_id: market_id, network_id: tournament_params[:network_id])
        market.id
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
          :rewards,
          :rules,
          market_ids: []
        )
    end
  end
end
