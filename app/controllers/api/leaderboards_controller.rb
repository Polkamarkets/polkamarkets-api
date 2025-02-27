module Api
  class LeaderboardsController < BaseController
    before_action :validate_params, only: [:index, :show, :winners]

    def index
      leaderboard = get_leaderboard(params[:network_id])

      render json: leaderboard, status: :ok
    end

    def show
      user_leaderboard = get_user_leaderboard(params[:network_id], params[:id])

      render json: user_leaderboard, status: :ok
    end

    private

    def tournament_leaderboard?
      params[:tournament_id].present?
    end

    def tournament_group_leaderboard?
      !tournament_leaderboard? && (params[:land_id].present? || params[:tournament_group_id].present?)
    end

    def leaderboard_record
      @leaderboard_record ||= tournament_leaderboard? ?
        Tournament.friendly.find(params[:tournament_id]) :
        TournamentGroup.friendly.find(params[:land_id] || params[:tournament_group_id])
    end

    def leaderboard_rank_by
      return @leaderboard_rank_by if @leaderboard_rank_by.present?

      # sorting params are comma separated
      sort_params = leaderboard_record.rank_by.split(',').map(&:to_sym)
      @leaderboard_rank_by =
        params[:rank_by].present? && sort_params.include?(params[:rank_by].to_sym) ?
          params[:rank_by].to_sym :
          sort_params.first
    end

    def get_leaderboard(network_id)
      raise "tournament network does not match" if leaderboard_record.network_id.to_i != network_id.to_i

      from_record = (pagination_params[:page] - 1) * pagination_params[:items]
      to_record = from_record + pagination_params[:items] - 1
      rank_by = (params[:rank_by] || leaderboard_rank_by).to_sym == :earnings_eur ? 'earnings' : 'won_predictions'
      sort = params[:sort] == 'asc' ? 'asc' : 'desc'

      leaderboard = tournament_leaderboard? ?
        LeaderboardService.new.get_tournament_leaderboard(
          network_id,
          leaderboard_record.id,
          from: from_record,
          to: to_record,
          rank_by: rank_by,
          sort: sort
        ) :
        LeaderboardService.new.get_tournament_group_leaderboard(
          network_id,
          leaderboard_record.id,
          from: from_record,
          to: to_record,
          rank_by: rank_by,
          sort: sort
        )

      # adding a ranking field to the user leaderboard
      leaderboard[:data].each_with_index do |l, index|
        l[:ranking] = l[:rank][leaderboard_rank_by]
      end

      # artificially creating an array with empty elements to paginate
      data = Array.new(leaderboard[:count])
      leaderboard[:data].each_with_index do |l, index|
        data[index + from_record] = l
      end

      paginate_array(data)
    end

    def get_user_leaderboard(network_id, user)
      user_leaderboard = tournament_leaderboard? ?
        LeaderboardService.new.get_tournament_leaderboard_user_entry(network_id, leaderboard_record.id, user) :
        LeaderboardService.new.get_tournament_group_leaderboard_user_entry(network_id, leaderboard_record.id, user)

      return user_not_found if user_leaderboard.blank?

      user_leaderboard[:ranking] = user_leaderboard[:rank][leaderboard_rank_by]
      user_leaderboard
    end

    def validate_params
      raise "network_id parameter is required" if params[:network_id].blank?
      raise "tournament or land parameters are required" if params[:tournament_id].blank? &&
        params[:land_id].blank? && params[:tournament_group_id].blank?
    end

    def user_not_found
      {
        user: params[:id],
        username: user_from_username&.username,
        user_image_url: user_from_username&.avatar,
        slug: user_from_username&.slug,
        volume_eur: 0,
        earnings_eur: 0,
        earnings_open_eur: 0,
        earnings_closed_eur: 0,
        claim_winnings_count: 0,
        transactions: 0,
        rank: {
          volume_eur: 0,
          earnings_eur: 0,
          claim_winnings_count: 0,
        }
      }
    end
  end
end
