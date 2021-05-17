# frozen_string_literal: true
module Api
  class MarketsController < BaseController
    def index
      markets = Market.published.order(created_at: :desc).includes(:outcomes).with_attached_image

      render json: markets, status: :ok
    end

    def show
      # finding items by eth market id
      market = Market.find_by_slug_or_eth_market_id(params[:id])

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
