class PortfolioStreakWorker
  include Sidekiq::Worker

  def perform(portfolio_id)
    portfolio = Portfolio.find_by(id: portfolio_id)
    return if portfolio.blank?

    TournamentGroup.where(network_id: portfolio.network_id).each do |tournament_group|
      next unless tournament_group.streaks_enabled?

      streaks = PortfolioStreakCalculatorService.new(portfolio_id, tournament_group.id).calculate_streaks(refresh: true)
      claims = Claim.where(network_id: portfolio.network_id, wallet_address: portfolio.eth_address, claim_type: 'streak')

      # going through streaks and creating claims
      streaks[:values].each do |streak_value|
        next unless streak_value[:completed]
        data = {
          tournament_group_id: tournament_group.id,
          date: streak_value[:date].to_time.to_i
        }

        next if claims.any? do |claim|
          claim.data.present? &&
          claim.data['tournament_group_id'] == data[:tournament_group_id] &&
          claim.data['date'] == data[:date]
        end

        token_address = Claim.get_wallet_address_preferred_token(
          portfolio.network_id,
          portfolio.eth_address,
          tournament_group.streaks_config['token_addresses']
        )

        Claim.create!(
          network_id: portfolio.network_id,
          wallet_address: portfolio.eth_address,
          amount: streak_value[:value],
          claim_type: 'streak',
          data: data,
          token_address: token_address
        )
      end
    end
  end
end
