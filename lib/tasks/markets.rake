namespace :markets do
  desc "checks for new markets and creates them"
  task :check_new_markets, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      # triggering a dummy events query for caching update purposes
      Bepro::PredictionMarketContractService.new(network_id: network_id).get_events(event_name: 'MarketCreated')

      eth_market_ids = Bepro::PredictionMarketContractService.new(network_id: network_id).get_all_market_ids.map(&:to_i)
      db_market_ids = Market.where(network_id: network_id).pluck(:eth_market_id)

      (eth_market_ids - db_market_ids).each do |market_id|
        Market.create_from_eth_market_id!(network_id, market_id)
      end
    end
  end

  desc "refreshes eth cache of markets"
  task :refresh_cache, [:symbol] => :environment do |task, args|
    Market.all.each { |m| m.refresh_cache! }
  end

  desc "refreshes markets news"
  task :refresh_news, [:symbol] => :environment do |task, args|
    Market.all.each { |m| m.refresh_news! }
  end
end
