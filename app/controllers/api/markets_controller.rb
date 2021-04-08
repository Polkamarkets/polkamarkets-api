# frozen_string_literal: true
module Api
  class MarketsController < BaseController
    def index
      markets = Market.all

      render json: markets, status: :ok
    end

    def show
      # finding items by eth market id
      market = Market.find_by(eth_market_id: params[:id])

      render json: market, status: :ok
    end
  end
end
