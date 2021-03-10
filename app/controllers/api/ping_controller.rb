# frozen_string_literal: true
module Api
  class PingController < BaseController
    def ping
      render json: { status: 'ok' }, status: :ok
    end
  end
end
