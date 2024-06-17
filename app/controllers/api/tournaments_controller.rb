module Api
  class TournamentsController < BaseController
    # TODO: add auth to endpoints
    # before_action :authenticate_user!, only: %i[create update destroy move_up move_down]

    def index
      # sorting by tournament_group position and tournament position
      tournaments = Tournament
        .includes(:tournament_group)
        .order('tournament_groups.position ASC, tournaments.position ASC')

      if params[:publish_status].present?
        if params[:publish_status] == 'published'
          tournaments = tournaments.published
        elsif params[:publish_status] == 'unpublished'
          tournaments = tournaments.unpublished
        end
      else
        tournaments = tournaments.published
      end

      if params[:token].present?
        tournaments = tournaments.select do |tournament|
          tournament.tokens.any? { |token| token[:symbol].downcase == params[:token].downcase }
        end
      end

      if params[:network_id].present?
        tournaments = tournaments.select do |tournament|
          tournament.network_id.to_i == params[:network_id].to_i
        end
      end

      render json: tournaments
    end

    def show
      tournament = Tournament.friendly.find(params[:id])

      render json: tournament
    end

    def show_markets
      tournament = Tournament.friendly.find(params[:id])

      markets = tournament.markets
        .includes(:outcomes)
        .includes(:tournaments)
        .includes(:comments)
        .includes(:likes)

      if params[:publish_status].present?
        if params[:publish_status] == 'published'
          markets = markets.published
        elsif params[:publish_status] == 'unpublished'
          markets = markets.unpublished
        end
      else
        markets = markets.published
      end

      markets = markets.select { |market| market.state == params[:state] } if params[:state]

      render json: markets,
        simplified_price_charts: true,
        hide_tournament_markets: true,
        scope: serializable_scope,
        status: :ok
    end

    def create
      create_params = tournament_params.except(:market_ids, :land_id)
      create_params[:tournament_group_id] = tournament_params[:land_id] if tournament_params[:land_id]

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

      update_params = tournament_params.except(:market_ids, :land_id)
      update_params[:tournament_group_id] = tournament_params[:land_id] if tournament_params[:land_id]

      network_id = tournament_params[:network_id] || tournament.network_id

      # converting market_ids to markets
      if !tournament_params[:market_ids].nil?
        update_params[:market_ids] = tournament_params[:market_ids].map do |market_id|
          market = Market.find_by!(eth_market_id: market_id, network_id: network_id)
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
          :land_id,
          :rank_by,
          :rules,
          :expires_at,
          :published,
          :comments_enabled,
          rewards: [:from, :to, :reward, :title, :description, :image_url],
          topics: [],
          market_ids: []
        )
    end
  end
end
