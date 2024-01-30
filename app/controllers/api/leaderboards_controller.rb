module Api
  class LeaderboardsController < BaseController
    before_action :validate_params, only: [:index, :show, :winners]

    def index
      leaderboard = get_leaderboard(params[:network_id])

      render json: leaderboard, status: :ok
    end

    def show
      user_leaderboard = get_user_leaderboard(params[:network_id], address_from_username || params[:id])

      render json: user_leaderboard, status: :ok
    end

    def winners
      blacklist = params[:blacklist].to_s.split(',').to_a.map(&:downcase)
      timeframe = params[:timeframe]
      network_id = params[:network_id].to_i

      timestamp = params[:timestamp].present? ?
        params[:timestamp].to_i :
        (timeframe == 'at' ?
          Time.now.to_i :
          (Time.now - 1.send(StatsService::TIMEFRAMES[timeframe])).to_i
        )

      leaderboards = StatsService.new.get_leaderboard(timeframe: params[:timeframe], timestamp: timestamp)
      leaderboard = leaderboards[network_id.to_i] || []

      network = Rails.application.config_for(:networks).find { |name, id| id == network_id }
      network = network ? network.first.to_s.capitalize : 'Unknown'

      winners = []

      # removing blacklisted wallets from leaderboard
      leaderboard.reject! { |user| blacklist.include?(user[:user].downcase) }

      rewards = Hash.new(0)

      StatsService::LEADERBOARD_PARAMS.each do |param, specs|
        rows = leaderboard.sort_by { |user| -user[param] }.select { |user| user[param] > 0 }[0..specs[:amount] - 1]
        next if rows.blank?

        rows.each_with_index do |winner, index|
          winners.push(
            {
              network: network,
              category: param,
              position: index + 1,
              address: winner[:user],
              reward: specs[:value]
            }
          )

          rewards[winner[:user]] += specs[:value]
        end
      end

      # mapping rewards to array
      rewards = rewards.map { |user, reward| { address: user, reward: reward } }

      render json: {
        winners: winners,
        rewards: rewards,
        period: {
          from: Time.at(StatsService.new.timestamp_from(timestamp, timeframe)).to_date,
          to: Time.at(StatsService.new.timestamp_to(timestamp, timeframe)).to_date
        }
      }, status: :ok
    end

    private

    def get_leaderboard(network_id, user = nil)
      leaderboards = StatsService.new.get_leaderboard(
        timeframe: params[:timeframe],
        tournament_id: params[:tournament_id],
      )

      leaderboard = leaderboards[network_id.to_i] || []

      achievements_service = Bepro::AchievementsContractService.new(network_id: network_id)
      if achievements_service.contract_address.present?
        # adding achievements to leaderboard data
        achievement_token_users = achievements_service.get_achievement_token_users
        achievement_tokens = AchievementToken
          .includes(:achievement)
          .where(network_id: network_id, eth_id: achievement_token_users.map { |token| token[:id] })

        leaderboard.each do |user|
          achievement_token_ids = achievement_token_users.select { |token| token[:user] == user[:user] }.map { |token| token[:id].to_i }
          user[:achievements] = achievement_tokens
            .select { |token| achievement_token_ids.include?(token.eth_id) }
            .map { |token| AchievementTokenSerializer.new(token).as_json }
        end
      else
        leaderboard.each do |user|
          user[:achievements] = []
        end
      end

      if user.present?
        user_data = User.where('lower(wallet_address) = ?', user.downcase).first

        user_leaderboard = leaderboard.find { |l| l[:user].downcase == user.downcase }

        return nil if user_leaderboard.blank?

        user_leaderboard[:username] = user_data&.username
        user_leaderboard[:user_image_url] = user_data&.avatar
        user_leaderboard[:slug] = user_data&.slug

        return user_leaderboard
      end

      users = User.pluck(:username, :wallet_address, :avatar, :slug)

      leaderboard.each do |user|
        user_data = users.find { |data| data[1].present? && data[1].downcase == user[:user].downcase }

        user[:username] = user_data ? user_data[0] : nil
        user[:user_image_url] = user_data ? user_data[2] : nil
        user[:slug] = user_data ? user_data[3] : nil
      end

      # removing blacklisted users from leaderboard
      leaderboard.reject! { |l| l[:user].in?(Rails.application.config_for(:ethereum).blacklist) }

      # removing users only with upvotes/downvotes
      leaderboard.reject! { |l| l[:transactions] == 0 }

      # sorting leaderboard, when tournament param is present
      if params[:tournament_id].present?
        tournament = Tournament.find(params[:tournament_id])

        raise "tournament network does not match" if tournament.network_id.to_i != network_id.to_i

        # sorting params are comma separated
        sort_params = tournament.rank_by.split(',').map(&:to_sym)

        leaderboard.sort_by! do |user|
          sort_params.map { |param| -user[param] }
        end
      end

      leaderboard
    end

    def get_user_leaderboard(network_id, username)
      leaderboard = get_leaderboard(params[:network_id])

      user_leaderboard = get_leaderboard(params[:network_id], username)

      return user_not_found if user_leaderboard.blank?

      # adding the rank per parameter to the user leaderboard
      rank = {
        markets_created: leaderboard.sort_by { |user| -user[:markets_created] }.index(user_leaderboard) + 1,
        volume_eur: leaderboard.sort_by { |user| -user[:volume_eur] }.index(user_leaderboard) + 1,
        tvl_volume_eur: leaderboard.sort_by { |user| -user[:tvl_volume_eur] }.index(user_leaderboard) + 1,
        tvl_liquidity_eur: leaderboard.sort_by { |user| -user[:tvl_liquidity_eur] }.index(user_leaderboard) + 1,
        earnings_eur: leaderboard.sort_by { |user| -user[:earnings_eur] }.index(user_leaderboard) + 1,
        claim_winnings_count: leaderboard.sort_by { |user| -user[:claim_winnings_count] }.index(user_leaderboard) + 1,
      }

      user_leaderboard[:rank] = rank

      user_leaderboard
    end

    def validate_params
      raise "timeframe parameter is required" if params[:timeframe].blank?
      raise "network_id parameter is required" if params[:network_id].blank?
    end

    def user_not_found
      {
        user: address_from_username || params[:id],
        username: user_from_username&.username,
        user_image_url: user_from_username&.avatar,
        slug: user_from_username&.slug,
        ens: nil,
        markets_created: 0,
        verified_markets_created: 0,
        volume_eur: 0,
        tvl_volume_eur: 0,
        earnings_eur: 0,
        liquidity_eur: 0,
        tvl_liquidity_eur: 0,
        claim_winnings_count: 0,
        transactions: 0,
        upvotes: 0,
        downvotes: 0,
        malicious: false,
        bankrupt: false,
        needs_rescue: false,
        achievements: [ ],
        rank: {
          markets_created: 0,
          volume_eur: 0,
          tvl_volume_eur: 0,
          tvl_liquidity_eur: 0,
          earnings_eur: 0,
          claim_winnings_count: 0,
        }
      }
    end
  end
end
