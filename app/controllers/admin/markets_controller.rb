module Admin
  class MarketsController < BaseController
    before_action :get_market, only: [:show, :edit, :update]

    def index
      @markets = Market.all
    end

    def show
    end

    def new
      @market = Market.new
      # creating 2 outcomes
      @market.outcomes << MarketOutcome.new
      @market.outcomes << MarketOutcome.new
    end

    def edit
    end

    def create
      @market = Market.create(market_params)

      if @market.persisted?
        redirect_to admin_market_path(id: @market.id), flash: { info: 'Market created successfully!' }
      else
        render :new
      end
    end

    def update
      if @market.update(market_params)
        redirect_to admin_market_path(id: @market.id)
      else
        render :edit
      end
    end

    def destroy
      # TODO
    end

    private

    def get_market
      @market = Market.find(params[:id])
    end

    def market_params
      params.require(:market).permit(
        :title,
        :description,
        :category,
        :subcategory,
        :expires_at,
        :image_url,
        outcomes_attributes: [:id, :title]
      )
    end
  end
end
