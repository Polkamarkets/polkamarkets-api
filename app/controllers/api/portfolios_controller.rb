# frozen_string_literal: true
module Api
  class PortfoliosController < BaseController
    def show
      portfolio = Portfolio.find_or_create_by!(eth_address: address)

      render json: portfolio, status: :ok
    end

    private

    def address
      # TODO: send through encrypted header
      @_address ||= params[:id]&.downcase
    end
  end
end
