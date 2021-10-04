namespace :markets do
  desc "checks for new markets and creates them"
  task :check_new_markets, [:symbol] => :environment do |task, args|
    eth_market_ids = Bepro::PredictionMarketContractService.new.get_all_market_ids.map(&:to_i)
    db_market_ids = Market.pluck(:eth_market_id)

    (eth_market_ids - db_market_ids).each do |market_id|
      Market.create_from_eth_market_id!(market_id)
    end
  end

  desc "refreshes eth cache of markets"
  task :refresh_cache, [:symbol] => :environment do |task, args|
    Market.all.each { |m| m.refresh_cache! }
  end
end
