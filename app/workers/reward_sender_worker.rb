class RewardSenderWorker
  include Sidekiq::Worker

  def perform()
    # Fetch data from claims table and use admin account to update RewardsDistributor smart contract
    claims = Claim.where(recorded_at: nil)

    claims.each do |claim|

      Bepro::RewardsDistributorContractService.new(network_id: claim.network_id)
        .add_claim_amount(claim.wallet_address, claim.amount, claim.token_address)

      claim.update(recorded_at: Time.now)
    end

  end
end
