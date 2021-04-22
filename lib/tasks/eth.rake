namespace :eth do
  desc "sc -> db: syncs database with contract data in blockchain"
  task :sync_db, [:symbol] => :environment do |task, args|
    raise 'eth:send :: this task should only be used locally!' if Rails.env.production?

    # THIS IS IRREVERSIBLE: all local data will be deleted
    Market.destroy_all

    # Clearing all caches
    $redis_store.keys('markets:*').each { |key| $redis_store.del key }
    $redis_store.keys('portfolios:*').each { |key| $redis_store.del key }

    market_ids = Ethereum::PredictionMarketContractService.new.get_all_market_ids
    market_ids.map { |market_id| Market.create_from_eth_market_id!(market_id) }
  end

  desc "db -> sc: seeds smart contract with database data"
  task :seed, [:symbol] => :environment do |task, args|
    raise 'eth:seed :: this task should only be used locally!' if Rails.env.production?

    # THIS IS IRREVERSIBLE: all local data will be deleted
    Market.destroy_all

    # Clearing all caches
    $redis_store.keys('markets:*').each { |key| $redis_store.del key }
    $redis_store.keys('portfolios:*').each { |key| $redis_store.del key }

    service = Ethereum::PredictionMarketContractService.new

    markets = JSON.parse(File.read(Rails.root.join("db/seeds_data/markets.json")))
    markets.map do |market_data|
      service.create_market(
        market_data['title'],
        market_data['outcomes'][0]['title'],
        market_data['outcomes'][1]['title'],
        duration: ((DateTime.parse(market_data['expires_at']) - DateTime.now) * 1.days).to_i,
        value: 1e17.to_i
      )

      # market_id - last market created
      market_id = service.get_all_market_ids.max
      # creating from smart contract data
      market = Market.create_from_eth_market_id!(market_id)
      market.update(
        category: market_data['category'],
        subcategory: market_data['subcategory'],
        image_url: market_data['image_url']
      )
      market
    end
  end
end
