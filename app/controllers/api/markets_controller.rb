module Api
  class MarketsController < BaseController
    before_action :get_market, only: %i[show reload feed]

    def index
      markets = Market
        .where(network_id: Rails.application.config_for(:ethereum).network_ids)
        .order(created_at: :desc)
        .includes(:outcomes)
        .includes(:tournaments)
        .includes(:comments)
        .includes(:likes)

      if params[:id]
        ids = params[:id].split(',').map(&:to_i)
        # filtering by a list of ids, comma separated
        markets = markets.where(eth_market_id: ids)
      elsif params[:publish_status].present?
        if params[:publish_status] == 'published'
          markets = markets.published
        elsif params[:publish_status] == 'unpublished'
          markets = markets.unpublished
        end
      else
        markets = markets.published
      end

      if params[:network_id]
        markets = markets.where(network_id: params[:network_id])
      end

      markets = markets.select { |market| market.state == params[:state] } if params[:state]

      if params[:token].present?
        markets = markets.select do |market|
          market.token.present? && market.token[:symbol].downcase == params[:token].downcase
        end
      end

      render json: markets,
        simplified_price_charts: true,
        hide_tournament_markets: true,
        scope: serializable_scope,
        status: :ok
    end

    def show
      render json: @market,
        show_price_charts: true,
        hide_tournament_markets: true,
        show_related_markets: true,
        scope: serializable_scope,
        status: :ok
    end

    def create
      # TODO: improve this, current issue is due indexing speed on RPC
      # trying 5 times with 3 second intervals
      market = nil
      5.times do |i|
        begin
          market = Market.create_from_eth_market_id!(params[:network_id], params[:id].to_i)
          break if market.present?
        rescue => e
          # only raise if it's the last iteration
          raise e if i == 4
          sleep(3)
        end
      end

      render json: market, serializer: MinifiedMarketSerializer, status: :ok
    end

    def draft
      # TODO: add admin auth
      create_params = market_params.except(:outcomes, :land_id, :tournament_id)

      tournament_group = TournamentGroup.find_by(id: market_params[:land_id])
      tournament = Tournament.find_by(id: market_params[:tournament_id])

      raise "Tournament or Land are not defined" if tournament_group.blank? || tournament.blank?

      market = Market.new(create_params)
      market_params[:outcomes].each do |outcome_params|
        market.outcomes.build(
          outcome_params.merge(draft_price: outcome_params[:price]).except(:price)
        )
      end

      market.save!
      tournament.markets << market

      render json: market,
        show_price_charts: true,
        hide_tournament_markets: true,
        show_related_markets: true,
        scope: serializable_scope,
        status: :ok
    end

    def update
      market = Market.find_by!(slug: params[:id])

      raise "Market is not in draft state" if market.eth_market_id.present?

      raise "Market has not enough outcomes" if market_params[:outcomes].count < 2

      update_params = market_params.except(:outcomes, :land_id, :tournament_id)
      # destroying outcomes and rebuilding them
      market.outcomes.destroy_all
      market_params[:outcomes].each do |outcome_params|
        market.outcomes.build(
          outcome_params.merge(draft_price: outcome_params[:price]).except(:price)
        )
      end
      market.update!(update_params)

      render json: market,
        show_price_charts: true,
        hide_tournament_markets: true,
        show_related_markets: true,
        scope: serializable_scope,
        status: :ok
    end

    def destroy
      market = Market.find_by!(slug: params[:id])

      raise "Market is not in draft state" if market.eth_market_id.present?

      market.destroy!

      render json: { status: 'ok' }, status: :ok
    end

    def reload
      # cleaning up total market cache
      # @market.destroy_cache!
      @market.refresh_cache!(queue: 'critical')

      render json: { status: 'ok' }, status: :ok
    end

    def feed
      render json: @market.feed, status: :ok
    end

    private

    def get_market
      @market = Market.find_by_slug_or_eth_market_id!(params[:id], params[:network_id])
    end

    def market_params
      params.require(:market).permit(
        :land_id,
        :tournament_id,
        :network_id,
        :expires_at,
        :title,
        :description,
        :category,
        :resolution_title,
        :resolution_source,
        :image_url,
        topics: [],
        outcomes: %i[title image_url price],
      )
    end
  end
end
