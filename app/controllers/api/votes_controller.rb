module Api
  class VotesController < BaseController
    def reload
      market = Market.find_by_slug_or_eth_market_id(params[:market_id])

      vote = market.vote.blank? ? Vote.create(market.id) : market.vote

      # forcing cache refresh of vote
      vote.refresh_cache!

      render json: { status: 'ok' }, status: :ok
    end
  end
end
