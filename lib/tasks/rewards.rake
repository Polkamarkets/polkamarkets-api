namespace :rewards do
  desc "computes the tournaments rewards for all tournament groups"
  task :compute_streaks, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      tournament_groups = TournamentGroup.where(network_id: network_id).select { |tg| tg.streaks_enabled? }
      next if tournament_groups.blank?

      from_block = args[:from_block].present? ?
        args[:from_block].to_i :
        Activity.max_block_number_by_network_id(network_id) - (
          Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :block_range) || 1000
        )

      actions = Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events(from_block: from_block)
      claim_amounts = {}

      tournament_groups.each do |tournament_group|
        market_ids = tournament_group.markets.pluck(:eth_market_id)
        tg_actions = actions.select { |action| market_ids.include?(action[:market_id]) }
        tg_users = tg_actions.map { |action| action[:address] }.uniq

        # TODO: improve performance
        tg_users.each do |address|
          portfolio = Portfolio.find_or_create_by!(eth_address: address.downcase, network_id: network_id)
          PortfolioStreakWorker.new.perform(portfolio.id)
          # triggering cache refresh
          portfolio.streaks(tournament_group.id, refresh: true)

          user_claims = Claim.where(network_id: network_id, wallet_address: address.downcase).group(:token_address).sum(:amount)
          user_claims.each do |token_address, amount|
            claim_amounts[token_address] ||= {}
            claim_amounts[token_address][address] = amount
          end
        end

        puts "claim_amounts"
        puts claim_amounts

        rewards_distributor = Bepro::RewardsDistributorContractService.new(network_id: network_id)
        claim_amounts.each do |token_address, amounts|
          # TODO: batch calls
          rewards_distributor.set_claim_amounts(
            amounts.keys,
            amounts.values,
            token_address
          )
        end
      end
    end
  end
end
