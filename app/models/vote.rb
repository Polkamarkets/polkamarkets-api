class Vote < ApplicationRecord

  belongs_to :market, inverse_of: :vote

  validates_uniqueness_of :market_id

  def self.create(market_id)
    vote = Vote.new(
      market_id: market_id
    )

    vote.save!

    vote
  end

  def refresh_cache!
    # TODO implement refresh

    # disabling cache delete for now
    # $redis_store.keys("markets:#{eth_market_id}*").each { |key| $redis_store.del key }

    # deleting from active serializer cache
    # $redis_store.keys("markets/#{id}*").each { |key| $redis_store.del key }
    # outcomes.each do |outcome|
    #   $redis_store.keys("market_outcomes/#{outcome.id}*").each { |key| $redis_store.del key }
    # end

    # # triggering a refresh for all cached ethereum data
    # Cache::MarketEthDataWorker.perform_async(id)
    # Cache::MarketOutcomePricesWorker.perform_async(id)
    # Cache::MarketActionEventsWorker.perform_async(id)
    # Cache::MarketPricesWorker.perform_async(id)
    # Cache::MarketLiquidityPricesWorker.perform_async(id)
    # Cache::MarketQuestionDataWorker.perform_async(id)
  end
end
