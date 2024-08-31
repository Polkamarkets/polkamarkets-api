namespace :cache do
  desc "refreshes cache of medium articles"
  task :refresh_articles, [:symbol] => :environment do |task, args|
    articles = MediumService.new.get_latest_articles
    Rails.cache.write("api:articles", articles, expires_in: 24.hours)
  end

  desc "refreshes cache of protocol stats"
  task :refresh_stats, [:symbol] => :environment do |task, args|
    stats = StatsService.new.get_stats
    Rails.cache.write("api:stats", stats)
  end

  desc "refreshes cache of open tournaments"
  task :refresh_tournament_stats, [:symbol] => :environment do |task, args|
    Tournament.all.each do |tournament|
      LeaderboardService.new.get_tournament_leaderboard(tournament.network_id, tournament.id, refresh: true)
    end
  end

  desc "refreshes cache of tournament_groups"
  task :refresh_tournament_group_stats, [:symbol] => :environment do |task, args|
    TournamentGroup.all.each do |tournament_group|
      LeaderboardService.new.get_tournament_group_leaderboard(tournament_group.network_id, tournament_group.id, refresh: true)
    end
  end

  desc "refreshes cache of network actions"
  task :refresh_actions, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.map do |network_id|
      actions = Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events
      Rails.cache.write("api:actions:#{network_id}", actions, expires_in: 24.hours)

      bonds = Bepro::RealitioErc20ContractService.new(network_id: network_id).get_bond_events
      Rails.cache.write("api:bonds:#{network_id}", bonds, expires_in: 24.hours)

      markets_resolved = Bepro::PredictionMarketContractService.new(network_id: network_id).get_market_resolved_events
      Rails.cache.write("api:markets_resolved:#{network_id}", markets_resolved, expires_in: 24.hours)

      if Rails.application.config_for(:ethereum).fantasy_enabled
        burn_events = Bepro::Erc20ContractService.new(network_id: network_id).burn_events
        Rails.cache.write("api:burn_actions:#{network_id}", burn_events, expires_in: 24.hours)

        mint_events = Bepro::Erc20ContractService.new(network_id: network_id).mint_events
        Rails.cache.write("api:mint_actions:#{network_id}", mint_events, expires_in: 24.hours)
      end

      # fetching users from last 24 hours and creating a Portfolio entry, in case it doesn't exist
      addresses = actions
        .select { |action| action[:timestamp] > 24. hours.ago.to_i }
        .map { |action| action[:address] } +
        bonds.select { |bond| bond[:timestamp] > 24. hours.ago.to_i }
        .map { |bond| bond[:user] }

      missing_addresses = addresses.uniq.map(&:downcase) - Portfolio.where(network_id: network_id).pluck(:eth_address)

      missing_addresses.uniq.each do |address|
        Portfolio.find_or_create_by(eth_address: address.downcase, network_id: network_id)
      end
    end
  end

  desc "refreshes cache of erc20 balances"
  task :refresh_erc20_balances, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.map do |network_id|
      actions = Rails.cache.fetch("api:actions:#{network_id}", expires_in: 24.hours) do
        Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events
      end

      addresses = actions.map { |action| action[:address] }.uniq
      addresses.each do |address|
        balance = Bepro::Erc20ContractService.new(network_id: network_id).balance_of(address)
        Rails.cache.write("api:erc20_balances:#{network_id}:#{address}", balance, expires_in: 24.hours)
      end
    end
  end
end
