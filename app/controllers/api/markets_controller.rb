# frozen_string_literal: true
module Api
  class MarketsController < BaseController
    def index
      markets = Market.all

      render json: markets.to_json(include: :items), status: :ok
    end

    def show
      market = Market.find(params[:id])

      render json: market.to_json(include: :items), status: :ok
    end
  end
end
