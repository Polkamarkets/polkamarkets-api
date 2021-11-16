namespace :market_list do
  desc "update verified markets on market list"
  task :update, [:symbol] => :environment do |task, args|
    market_list = MarketListService.new(Rails.application.config_for(:ethereum).market_list_url)

    market_ids = Market.where(eth_market_id: market_list.market_ids).pluck(:id)
    market_ids += Market.where(slug: market_list.market_slugs).pluck(:id)
    market_ids.uniq!

    Market.where(id: market_ids).update_all(verified: true)
    Market.where.not(id: market_ids).update_all(verified: false)
  end
end
