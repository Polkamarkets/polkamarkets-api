# frozen_string_literal: true
module Api
  class IpfsController < BaseController
    def add
      raise "File not received" if params[:file].blank?

      # upload received file to ipfs
      response = IpfsService.new.add(params[:file])

      render json: response, status: :ok
    end
  end
end
