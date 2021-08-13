# frozen_string_literal: true
module Api
  class WebhooksController < BaseController
    def faucet
      Erc20FaucetService.new.transfer_or_ignore(params[:user], params[:content])

      head :ok
    end
  end
end
