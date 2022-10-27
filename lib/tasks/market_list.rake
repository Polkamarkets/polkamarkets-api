namespace :market_list do
  desc "update verified markets on market list"
  task :update, [:symbol] => :environment do |task, args|
    market_list = MarketListService.new(Rails.application.config_for(:ethereum).market_list_url)

    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      market_ids = Market.where(eth_market_id: market_list.market_ids(network_id.to_i)).pluck(:id)
      market_ids += Market.where(slug: market_list.market_slugs(network_id.to_i)).pluck(:id)
      # fetching all markets with a positive delta of votes
      market_ids += Market.where(network_id: network_id).select do |market|
        market.votes_delta >= Rails.application.config_for(:ethereum).voting_delta
      end.pluck(:id)

      market_ids.uniq!

      Market.where(network_id: network_id).where(id: market_ids).update_all(verified: true)
      Market.where(network_id: network_id).where.not(id: market_ids).update_all(verified: false)
    end
  end
end
