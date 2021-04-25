# frozen_string_literal: true
module Api
  class WhitelistController < BaseController
    def show
      # checking if an address is whitelist for beta testing
      whitelist_status = WhitelistService.new(params[:id]).whitelisted_status

      render json: whitelist_status, status: :ok
    end
  end
end
