class TournamentRewardsService
  include BigNumberHelper

  def initialize(tournament_id)
    @tournament = Tournament.find(tournament_id)
    @network_id = @tournament.network_id
    @leaderboard_service = LeaderboardService.new
  end

  # Calculate winners for all reward tiers and distribute rewards
  def distribute_rewards
    return unless should_distribute_rewards?

    Rails.logger.info "Starting rewards distribution for tournament #{@tournament.id}"

    # Get winners for each reward tier
    winners = calculate_winners

    # distributing rewards in a single transaction
    distribute_rewards(winners)

    # Distribute rewards for each tier
    winners_by_tier.each do |rank_by, winners|
      next if winners.empty?

      distribute_tier_rewards(rank_by, winners)
    end

    # Mark tournament as rewards distributed
    @tournament.update!(rewards_distributed: true, rewards_distributed_at: Time.current)

    Rails.logger.info "Successfully distributed rewards for tournament #{@tournament.id}"
  rescue => e
    Rails.logger.error "Failed to distribute rewards for tournament #{@tournament.id}: #{e.message}"
    Sentry.capture_exception(e) if defined?(Sentry)
    raise e
  end

  private

  def should_distribute_rewards?
    return false unless @tournament.auto_distribute_rewards?
    return false unless @tournament.resolved?
    return false if @tournament.rewards.blank?
    return false if @tournament.rewards_distributed?
    return false if @tournament.rewards_token_address.blank?

    true
  end

  def calculate_winners
    winners = []

    @tournament.rewards.each do |reward|
      rank_by = reward['rank_by'] == 'earnings_eur' ? 'earnings' : 'won_predictions'
      from_rank = reward['from']
      to_rank = reward['to']
      value = reward['value']
      next if value.blank?

      # Get leaderboard for this ranking criteria
      leaderboard = @leaderboard_service.get_tournament_leaderboard(
        @network_id,
        @tournament.id,
        from: from_rank - 1, # Convert to 0-based index
        to: to_rank - 1,
        rank_by: rank_by,
        sort: 'desc',
        refresh: true
      )

      leaderboard[:data].each do |entry|
        # checking user record in database. if there's an idp record, use that address, otherwise use the wallet address
        user = User.find_by(wallet_address: entry[:user])
        address = user.user_idps.where(provider: 'custom_auth').first&.uid || entry[:user]

        winners << {
          user_id: user.id,
          address: address,
          rank: entry[:ranking],
          value: value,
          rank_by: rank_by
        }
      end
    end

    winners
  end

  def distribute_rewards(winners)
    Rails.logger.info "Distributing rewards for #{winners.count} winners"

    recipients = winners.map { |w| w[:address] }
    amounts = winners.map { |w| w[:value] }

    # Check if contract has sufficient balance
    total_amount = disperse_service.calculate_total_amount(amounts)

    unless disperse_service.sufficient_token_balance?(token_address, total_amount)
      raise "Insufficient token balance for distribution. Required: #{total_amount}"
    end

    disperse_service = Bepro::DisperseContractService.new(network_id: @network_id)
    result = disperse_service.disperse_tokens(@tournament.rewards_token_address, recipients, amounts)

    # Create distribution record for tracking
    @tournament.update!(
      rewards_distribution: winners,
      rewards_distribution_tx_id: result['transactionHash'],
      rewards_distributed: true
    )
  end


  def distribute_tokens(token_address, recipients, amounts, reward)
    disperse_service = Bepro::DisperseContractService.new(network_id: @network_id)

    # Check if contract has sufficient balance
    total_amount = disperse_service.calculate_total_amount(amounts)

    unless disperse_service.sufficient_token_balance?(token_address, total_amount)
      raise "Insufficient token balance for distribution. Required: #{total_amount}"
    end

    # Execute the distribution
    result = disperse_service.disperse_tokens(token_address, recipients, amounts)

    # Log the distribution
    Rails.logger.info "Distributed #{total_amount} tokens to #{recipients.count} recipients"
    Rails.logger.info "Transaction hash: #{result['transactionHash']}"

    # Create distribution record for tracking
    create_distribution_record(token_address, recipients, amounts, reward, result['transactionHash'])
  end

  def create_distribution_record(token_address, recipients, amounts, reward, transaction_hash)
    # You might want to create a model to track distributions
    # For now, we'll just log it
    Rails.logger.info "Distribution record:"
    Rails.logger.info "  Token: #{token_address}"
    Rails.logger.info "  Reward: #{reward['title']}"
    Rails.logger.info "  Recipients: #{recipients.count}"
    Rails.logger.info "  Total amount: #{amounts.sum}"
    Rails.logger.info "  Transaction: #{transaction_hash}"
  end
end
