module Api
  class MarketsController < BaseController
    before_action :get_market, only: %i[show comments holders reload reload_prices feed]
    before_action :authenticate_admin!, only: %i[draft update destroy feature unfeature]
    before_action :authenticate_user!, only: %i[publish]

    def index
      markets = Market
        .where(network_id: Rails.application.config_for(:ethereum).network_ids)
        .order(created_at: :desc)
        .includes(:outcomes)
        .includes(:tournaments)

      if params[:id]
        ids = params[:id].split(',').map(&:to_i)
        # filtering by a list of ids, comma separated
        markets = markets.where(eth_market_id: ids)
      elsif params[:publish_status].present?
        if params[:publish_status] == 'published'
          markets = markets.published
        elsif params[:publish_status] == 'unpublished'
          markets = markets.unpublished
        end
      else
        markets = markets.published
      end

      if params[:network_id]
        markets = markets.where(network_id: params[:network_id])
      end

      markets = markets.select { |market| market.state == params[:state] } if params[:state]

      if params[:token].present?
        markets = markets.select do |market|
          market.token.present? && market.token[:symbol].downcase == params[:token].downcase
        end
      end

      render json: markets,
        simplified_price_charts: true,
        hide_tournament_markets: true,
        scope: serializable_scope,
        status: :ok
    end

    def show
      render json: @market,
        show_price_charts: true,
        hide_tournament_markets: true,
        show_related_markets: true,
        scope: serializable_scope,
        status: :ok
    end

    def comments
      render json: @market.comments, scope: serializable_scope, status: :ok
    end

    def holders
      # fetching top 20 holders from each outcome and serializing users
      holders = {}

      @market.holders.each do |outcome_id, outcome_holders|
        outcome_holders = outcome_holders.first(20).to_h
        users = User.where(wallet_address: outcome_holders.keys)
        holders[outcome_id] = []

        outcome_holders.each do |address, amount|
          user = users.find { |u| u.wallet_address == address }
          holders[outcome_id] << {
            address: address,
            shares: amount,
            user: user.present? ? UserSerializer.new(user).as_json : nil
          }
        end
      end

      render json: holders, status: :ok
    end

    def create
      # TODO: improve this, current issue is due indexing speed on RPC
      # trying 5 times with 3 second intervals
      market = nil
      5.times do |i|
        begin
          market = Market.create_from_eth_market_id!(params[:network_id], params[:id].to_i)
          break if market.present?
        rescue => e
          # only raise if it's the last iteration
          raise e if i == 4
          sleep(3)
        end
      end

      render json: market, serializer: MinifiedMarketSerializer, status: :ok
    end

    def draft
      # TODO: add admin auth
      create_params = market_params.except(:outcomes, :land_id, :tournament_id)
      market_draft_params.each do |key, value|
        create_params["draft_#{key}"] = value if value.present?
      end

      tournament_group = TournamentGroup.find_by(id: market_params[:land_id])
      tournament = Tournament.find_by(id: market_params[:tournament_id])

      raise "Tournament or Land are not defined" if tournament_group.blank? || tournament.blank?

      market = Market.new(create_params)
      market_params[:outcomes].each do |outcome_params|
        market.outcomes.build(
          outcome_params.merge(draft_price: outcome_params[:price]).except(:price)
        )
      end

      market.save!
      tournament.markets << market

      render json: market,
        show_price_charts: true,
        hide_tournament_markets: true,
        show_related_markets: true,
        scope: serializable_scope,
        status: :ok
    end

    def publish
      markets = Market.where(slug: params[:slugs])

      # making sure all markets exist
      raise "Market not found" if markets.count != params[:slugs].count

      # making sure user is admin of all markets
      markets.each do |market|
        raise "User is not admin of market #{market.slug}" unless market.admins.any? { |admin| admin.downcase == current_user.wallet_address.downcase }
      end

      # making sure all markets are in draft state
      markets.each do |market|
        raise "Market is not in draft state" if market.eth_market_id.present? || market.publish_status == 'published'
      end

      markets.each { |market| market.update!(publish_status: 'pending') }

      render json: { status: 'ok' }, status: :ok
    end

    def update
      market = Market.find_by!(slug: params[:id])

      raise "Market is not in draft state" if market.eth_market_id.present?

      raise "Market has not enough outcomes" if market_params[:outcomes].count < 2

      update_params = market_params.except(:outcomes, :land_id, :tournament_id)
      market_draft_params.each do |key, value|
        update_params["draft_#{key}"] = value if value.present?
      end

      # update slug
      update_params[:slug] = nil if update_params[:title].present?

      # destroying outcomes and rebuilding them
      market.outcomes.destroy_all
      market_params[:outcomes].each do |outcome_params|
        market.outcomes.build(
          outcome_params.merge(draft_price: outcome_params[:price]).except(:price)
        )
      end
      market.update!(update_params)

      render json: market,
        show_price_charts: true,
        hide_tournament_markets: true,
        show_related_markets: true,
        scope: serializable_scope,
        status: :ok
    end

    def destroy
      market = Market.find_by!(slug: params[:id])

      raise "Market is not in draft state" if market.eth_market_id.present?

      market.destroy!

      render json: { status: 'ok' }, status: :ok
    end

    def reload
      # cleaning up total market cache
      # @market.destroy_cache!
      @market.refresh_cache!(queue: 'critical')

      render json: { status: 'ok' }, status: :ok
    end

    def reload_prices
      @market.refresh_prices!(queue: 'critical')

      render json: { status: 'ok' }, status: :ok
    end

    def feed
      render json: @market.feed, status: :ok
    end

    def feature
      market = Market.find_by!(slug: params[:id])

      market.update!(featured: true)

      # disabling this for now
      # unfeaturing all other markets from same contest
      # market.tournaments.each do |tournament|
      #   tournament.markets.where.not(id: market.id).each { |m| m.update!(featured: false) }
      # end

      render json: { status: 'ok' }, status: :ok
    end

    def unfeature
      market = Market.find_by!(slug: params[:id])

      market.update!(featured: false)

      render json: { status: 'ok' }, status: :ok
    end

    private

    def get_market
      @market = Market.find_by_slug_or_eth_market_id!(params[:id], params[:network_id])
    end

    def market_params
      params.require(:market).permit(
        :land_id,
        :tournament_id,
        :network_id,
        :expires_at,
        :title,
        :description,
        :category,
        :resolution_title,
        :resolution_source,
        :image_url,
        :scheduled_at,
        topics: [],
        outcomes: %i[title image_url price],
      )
    end

    def market_draft_params
      params.require(:market).permit(
        :liquidity,
        :timeout,
      )
    end
  end
end
