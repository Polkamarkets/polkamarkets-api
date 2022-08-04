module Api
  class PortfoliosController < BaseController
    def show
      portfolio = Portfolio.find_or_create_by!(eth_address: address, network_id: params[:network_id])

      render json: portfolio, status: :ok
    end

    def feed
      portfolio = Portfolio.find_or_create_by!(eth_address: address, network_id: params[:network_id])

      render json: portfolio.feed_events, status: :ok
    end

    def reload
      # forcing cache refresh of market
      portfolio = Portfolio.find_by!(eth_address: address, network_id: params[:network_id])
      portfolio.refresh_cache!

      render json: { status: 'ok' }, status: :ok
    end

    private

    def address
      # TODO: send through encrypted header
      @_address ||= params[:id]&.downcase
    end
  end
end
