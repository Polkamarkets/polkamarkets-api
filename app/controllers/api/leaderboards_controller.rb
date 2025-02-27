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

    def get_leaderboard(network_id, user = nil)
      raise "tournament network does not match" if leaderboard_record.network_id.to_i != network_id.to_i

      leaderboard = tournament_leaderboard? ?
        LeaderboardService.new.get_tournament_leaderboard(network_id, leaderboard_record.id) :
        LeaderboardService.new.get_tournament_group_leaderboard(network_id, leaderboard_record.id)

      # sorting params are comma separated
      rank_by = leaderboard_record.rank_by
      sort_params = rank_by.split(',').map(&:to_sym)

      if params[:rank_by].present? && sort_params.include?(params[:rank_by].to_sym)
        # moving the rank_by param to the first position
        sort_params.delete(params[:rank_by].to_sym)
        sort_params.unshift(params[:rank_by].to_sym)
      end

      if tournament_leaderboard?
        # removing blacklisted users from the leaderboard
        blacklist = Rails.application.config_for(:ethereum).dig(
          :tournament_blacklists,
          leaderboard_record.id.to_s.to_sym,
          sort_params.first.to_sym,
        ) || []

        leaderboard.select! { |user| !blacklist.include?(user[:user]) }
      end

      leaderboard.sort_by! do |user|
        sort_params.map { |param| -user[param] }
      end

        # adding a rank field to the user leaderboard
      leaderboard.each_with_index do |user, index|
        user[:ranking] = index + 1
      end

      if params[:rank_by].present? && params[:rank_by] != rank_by
        sort_params = params[:rank_by].split(',').map(&:to_sym)

        leaderboard.sort_by! do |user|
          sort_params.map { |param| -user[param] }
        end
      end

      if params[:sort] == 'asc'
        leaderboard.reverse!
      end

      # TODO: remove - making it optional for legacy reasons
      return paginate_array(leaderboard) if params[:paginate]

      leaderboard
    end

    def get_user_leaderboard(network_id, user)
      user_leaderboard = tournament_leaderboard? ?
        LeaderboardService.new.get_tournament_leaderboard_user_entry(network_id, leaderboard_record.id, user) :
        LeaderboardService.new.get_tournament_group_leaderboard_user_entry(network_id, leaderboard_record.id, user)

      return user_not_found if user_leaderboard.blank?

      # sorting params are comma separated
      sort_params = leaderboard_record.rank_by.split(',').map(&:to_sym)
      rank_by = params[:rank_by].present? && sort_params.include?(params[:rank_by].to_sym) ?
        params[:rank_by].to_sym :
        sort_params.first

      user_leaderboard[:ranking] = user_leaderboard[:rank][rank_by]

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
