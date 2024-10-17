class RewardSenderWorker
  include Sidekiq::Worker

  def perform()
    # Fetch data from claims table and use admin account to update RewardsDistributor smart contract
    claims = Claim.where(recorded_at: nil)

    prefered_token = '0xcE4B831305b607788847e802A1869e93c40cfC83' # TODO how to get prefered_token???

    claims.each do |claim|

      Bepro::RewardsDistributorContractService.new(network_id: claim.network_id)
        .add_claim_amount(claim.wallet_address, claim.amount, prefered_token)

      claim.update(recorded_at: Time.now)
    end

  end
end
