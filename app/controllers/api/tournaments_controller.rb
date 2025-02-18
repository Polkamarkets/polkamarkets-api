module Api
  class TournamentsController < BaseController
    before_action :authenticate_admin!, only: %i[create update destroy move_up move_down]

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

      if params[:network_id].present?
        tournaments = tournaments.select do |tournament|
          tournament.network_id.to_i == params[:network_id].to_i
        end
      end

      if params[:token].present?
        tournaments = tournaments.select do |tournament|
          tournament.token.present? && tournament.token[:symbol].downcase == params[:token].downcase
        end
      end

      render json: tournaments
    end

    def show
      tournament = Tournament.friendly.find(params[:id])

      render json: tournament
    end

    def accuracy_report
      tournament = Tournament.friendly.find(params[:id])

      accuracy_report = tournament
        .markets
        .select { |m| m.resolved? && m.published? }
        .map(&:accuracy_report)
        .join("\n")

      render json: accuracy_report
    end

    def show_markets
      tournament = Tournament.friendly.find(params[:id])

      markets = tournament.markets
        .includes(:outcomes)
        .includes(:tournaments)

      if params[:publish_status].present?
        if params[:publish_status] == 'published'
          markets = markets.published
        elsif params[:publish_status] == 'unpublished'
          markets = markets.unpublished
        end
      else
        markets = markets.published
      end

      markets = markets.select { |market| market.state == params[:state] } if params[:state].present? && params[:state] != 'all'

      render json: markets,
        simplified_price_charts: !!params[:show_price_charts],
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

      should_update_markets_cache = !tournament.published? && tournament_params[:published]

      # update slug if title changes and tournament is not published
      if update_params[:title] && update_params[:title] != tournament.title && !tournament.published?
        tournament.slug = nil
      end

      if tournament.update(update_params)
        if should_update_markets_cache
          # triggering a cache refresh for all markets in the tournament
          tournament.markets.each do |market|
            Cache::MarketRefreshPricesWorker.perform_async(market.id)
          end
        end

        render json: tournament
      else
        render json: tournament.errors, status: :unprocessable_entity
      end
    end

    def add_market
      raise 'Market ID is required' unless params[:market_id]

      tournament = Tournament.friendly.find(params[:id])

      market = Market.find_by!(eth_market_id: params[:market_id], network_id: tournament.network_id)

      tournament.markets << market unless tournament.markets.include?(market)

      render json: tournament
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
          :avatar_url,
          :network_id,
          :land_id,
          :rank_by,
          :rules,
          :expires_at,
          :published,
          :comments_enabled,
          rewards: [:from, :to, :reward, :title, :description, :image_url, :rank_by, :label],
          topics: [],
          market_ids: []
        )
    end
  end
end
