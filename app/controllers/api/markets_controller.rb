module Api
  class MarketsController < BaseController
    before_action :get_market, only: %i[show reload feed]

    def index
      markets = Market
        .published
        .order(created_at: :desc)
        .includes(:outcomes)
        .includes(:tournaments)
        .includes(:comments)

      if params[:id]
        ids = params[:id].split(',').map(&:to_i)
        # filtering by a list of ids, comma separated
        markets = markets.where(eth_market_id: ids)
      end

      if params[:network_id]
        markets = markets.where(network_id: params[:network_id])
      end

      if params[:state]
        # when open, using database field to filter, otherwise using eth data
        case params[:state]
        when 'open'
          markets = markets.open
        else
          markets = markets.select { |market| market.state == params[:state] }
        end
      end

      render json: markets,
        scope: { simplified_price_charts: true, hide_tournament_markets: true },
        each_serializer: MarketIndexSerializer, status: :ok
    end

    def show
      render json: @market, scope: { show_price_charts: true, hide_tournament_markets: true }, status: :ok
    end

    def create
      market = Market.create_from_eth_market_id!(params[:network_id], params[:id].to_i)

      render json: market, serializer: MinifiedMarketSerializer, status: :ok
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
  end
end
