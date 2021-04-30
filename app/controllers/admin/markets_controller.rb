module Admin
  class MarketsController < BaseController
    before_action :get_market, only: [:show, :edit, :update, :publish, :resolve]

    def index
      @markets = Market.order(created_at: :desc)
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
        redirect_to admin_markets_path, flash: { info: 'Market successfully created!' }
      else
        render :new
      end
    end

    def update
      if @market.update(market_params)
        redirect_to admin_markets_path, flash: { info: 'Market successfully updated!' }
      else
        render :edit
      end
    end

    def destroy
      # TODO
    end

    def publish
      raise "Ethereum Market not received!" if params[:eth_market_id].blank?
      raise "Market #{@market.id} already has a Ethereum Market assigned!" if @market.eth_market_id.present?

      eth_market_id = params[:eth_market_id].to_i
      eth_market_data = Ethereum::PredictionMarketContractService.new.get_market(eth_market_id)

      if eth_market_data[:title] != @market.title ||
        eth_market_data[:outcomes].each_with_index.any? { |outcome, index| outcome[:title] != @market.outcomes[index].title }
        raise "Market #{@market.id} and Ethereum Market #{eth_market_id} do not match data!"
      end

      # TODO: wrap all in transaction
      @market.update!(eth_market_id: eth_market_id)
      eth_market_data[:outcomes].each_with_index do |outcome, index|
        @market.outcomes[index].update!(eth_market_id: outcome[:id])
      end

      redirect_to admin_markets_path, flash: { info: 'Market successfully published!' }
    end

    def resolve
      @market.refresh_cache!

      redirect_to admin_markets_path, flash: { info: 'Market successfully resolved!' }
    end

    private

    def get_market
      @market = Market.friendly.find(params[:id])
    end

    def market_params
      params.require(:market).permit(
        :title,
        :description,
        :expires_at,
        :published_at,
        :oracle_source,
        :category,
        :subcategory,
        :expires_at,
        :image_url,
        :image,
        outcomes_attributes: [:id, :title]
      )
    end
  end
end
