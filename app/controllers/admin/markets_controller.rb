module Admin
  class MarketsController < BaseController
    def index
      @markets = Market.all
    end

    def show
    end
  end
end
