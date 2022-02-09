namespace :eth do
  desc "sc -> db: syncs database with contract data in blockchain"
  task :sync_db, [:symbol] => :environment do |task, args|
    raise 'eth:send :: this task should only be used locally!' if Rails.env.production?

    # THIS IS IRREVERSIBLE: all local data will be deleted
    Market.destroy_all

    # Clearing all caches
    $redis_store.keys('markets:*').each { |key| $redis_store.del key }
    $redis_store.keys('portfolios:*').each { |key| $redis_store.del key }

    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      market_ids = Bepro::PredictionMarketContractService.new(network_id: network_id).get_all_market_ids
      market_ids.map { |market_id| Market.create_from_eth_market_id!(network_id, market_id) }
    end
  end
end
