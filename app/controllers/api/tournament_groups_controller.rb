module Api
  class TournamentGroupsController < BaseController
    # TODO: add auth to endpoints
    # before_action :authenticate_user!, only: %i[create update destroy move_up move_down]

    def index
      tournament_groups = TournamentGroup.order(position: :asc).all

      if params[:admin].present?
        tournament_groups = tournament_groups.select do |tournament_group|
          tournament_group.admins.any? { |admin| admin.downcase == params[:admin].downcase }
        end
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

      render json: tournament_groups, show_tournaments: true
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
        .includes(:comments)
        .includes(:likes)
      markets = markets.select { |market| market.state == params[:state] } if params[:state]

      render json: markets,
        simplified_price_charts: true,
        hide_tournament_markets: true,
        scope: serializable_scope,
        status: :ok
    end

    def create
      tournament_group = TournamentGroup.new(tournament_group_params)

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
        tags: [],
        social_urls: {},
      )
    end
  end
end
