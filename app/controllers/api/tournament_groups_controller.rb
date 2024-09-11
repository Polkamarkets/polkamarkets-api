module Api
  class TournamentGroupsController < BaseController
    # TODO: add auth to endpoints
    # before_action :authenticate_user!, only: %i[create update destroy move_up move_down]
    before_action :authenticate_user!, only: %i[join create]

    def index
      tournament_groups = TournamentGroup.order(position: :asc).all
      show_redeem_code = false

      if params[:admin].present?
        tournament_groups = tournament_groups.select do |tournament_group|
          tournament_group.admins.any? { |admin| admin.downcase == params[:admin].downcase }
        end
        show_redeem_code = true
      elsif params[:publish_status].present?
        if params[:publish_status] == 'published'
          tournament_groups = tournament_groups.published
        elsif params[:publish_status] == 'unpublished'
          tournament_groups = tournament_groups.unpublished
        end
      else
        tournament_groups = tournament_groups.published
      end

      if params[:token].present?
        tournament_groups = tournament_groups.select do |tournament_group|
          tournament_group.tokens.any? { |token| token[:symbol].downcase == params[:token].downcase }
        end
      end

      if params[:network_id].present?
        tournament_groups = tournament_groups.select do |tournament_group|
          tournament_group.network_id.to_i == params[:network_id].to_i
        end
      end

      render json: tournament_groups, show_tournaments: true, show_redeem_code: show_redeem_code
    end

    def show
      tournament_group = TournamentGroup.friendly.find(params[:id])

      render json: tournament_group, show_tournaments: true
    end

    def show_markets
      tournament_group = TournamentGroup.friendly.find(params[:id])

      markets = tournament_group.markets
        .includes(:outcomes)
        .includes(:tournaments)

      if params[:publish_status].present?
        if params[:publish_status] == 'published'
          markets = markets.published
        elsif params[:publish_status] == 'unpublished'
          markets = markets.unpublished
        end
      else
        markets = markets.published
      end

      markets = markets.select { |market| market.state == params[:state] } if params[:state]

      render json: markets,
        simplified_price_charts: true,
        hide_tournament_markets: true,
        scope: serializable_scope,
        status: :ok
    end

    def create
      prediction_market_controller_contract_service =
        Bepro::PredictionMarketControllerContractService.new(network_id: params[:land][:network_id])

      created_land = prediction_market_controller_contract_service.create_land(params[:land][:title], params[:land][:symbol])

      @token_address = created_land['events']['LandCreated'][0]['returnValues']['token']

      tournament_group = TournamentGroup.new(tournament_group_params)
      tournament_group.token_address = @token_address

      if params[:land][:everyone_can_create_markets]
        prediction_market_controller_contract_service.set_land_everyone_can_create_markets(@token_address, true)
      end

      # add user as admin
      prediction_market_controller_contract_service.add_admin_to_land(@token_address, current_user.wallet_address)

      if tournament_group.save
        render json: tournament_group, status: :created
      else
        render json: tournament_group.errors, status: :unprocessable_entity
      end
    end

    def update
      tournament_group = TournamentGroup.friendly.find(params[:id])

      if tournament_group.update(tournament_group_params)
        render json: tournament_group
      else
        render json: tournament_group.errors, status: :unprocessable_entity
      end
    end

    def update_featured_markets
      tournament_group = TournamentGroup.friendly.find(params[:id])

      markets = Market.where(network_id: tournament_group.network_id, eth_market_id: params[:market_ids])

      tournament_group.markets.update_all(featured: false)
      markets.update_all(featured: true)

      render json: tournament_group
    end

    def destroy
      tournament_group = TournamentGroup.friendly.find(params[:id])

      tournament_group.destroy
    end

    def move_up
      tournament_group = TournamentGroup.friendly.find(params[:id])
      tournament_group.move_higher

      render json: tournament_group
    end

    def move_down
      tournament_group = TournamentGroup.friendly.find(params[:id])
      tournament_group.move_lower

      render json: tournament_group
    end

    def join
      tournament_group = TournamentGroup.friendly.find(params[:id])

      tournament_group.users << current_user unless tournament_group.users.include?(current_user)
      tournament_group.update_counters

      render json: tournament_group
    end

    private

    def tournament_group_params
      params.require(:land).permit(
        :id,
        :title,
        :description,
        :short_description,
        :slug,
        :image_url,
        :banner_url,
        :website_url,
        :published,
        :onboarded,
        :network_id,
        tags: [],
        social_urls: {},
      )
    end
  end
end
