# frozen_string_literal: true
module Api
  class MarketsController < BaseController
    def index
      markets = Market.published.order(created_at: :desc).includes(:outcomes).with_attached_image

      if params[:id]
        ids = params[:id].split(',').map(&:to_i)
        # filtering by a list of ids, comma separated
        markets = markets.where(eth_market_id: ids)
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

      render json: markets, status: :ok
    end

    def show
      # finding items by eth market id
      market = Market.find_by_slug_or_eth_market_id(params[:id])

      render json: market, status: :ok
    end

    def create
      market = Market.create_from_eth_market_id!(params[:id].to_i)

      render json: market, status: :ok
    end

    def reload
      # forcing cache refresh of market
      market = Market.find_by_slug_or_eth_market_id(params[:id])
      market.refresh_cache!

      render json: { status: 'ok' }, status: :ok
    end
  end
end
