module Api
  class PortfoliosController < BaseController
    def show
      raise ActiveRecord::RecordNotFound unless address.start_with?('0x')

      if !allowed_network?
        render json: Portfolio.empty_portfolio(address, params[:network_id]), status: :ok
        return
      end

      portfolio = Portfolio.find_or_create_by!(eth_address: address, network_id: params[:network_id])

      render json: portfolio, status: :ok
    end

    def feed
      raise ActiveRecord::RecordNotFound unless address.start_with?('0x')

      portfolio = Portfolio.find_or_create_by!(eth_address: address, network_id: params[:network_id])

      events = allowed_network? ? portfolio.feed_events : []

      render json: params[:paginate] ? paginate_array(events) : events, status: :ok
    end

    def reload
      # forcing cache refresh of market
      portfolio = Portfolio.find_or_create_by!(eth_address: address, network_id: params[:network_id])
      # portfolio.refresh_cache!(queue: 'critical')

      render json: { status: 'ok' }, status: :ok
    end

    private

    def address
      @_address ||= address_from_username || params[:id]&.downcase
    end
  end
end
