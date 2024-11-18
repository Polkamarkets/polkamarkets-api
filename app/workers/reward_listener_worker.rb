class RewardListenerWorker
  include Sidekiq::Worker

  def perform
    # Fetch data from claims table and use admin account to update RewardsDistributor smart contract
    claims = Claim.where.not(recorded_at: nil)
        .where(claimed: false)
        .order(:recorded_at)
        .group_by { |claim| [claim.network_id, claim.wallet_address] }

    claims.each do |(network_id, wallet_address), claims|
      # get claimed events from get_claimed_events function on RewardsDistributorContractService
      claimed_events = Bepro::RewardsDistributorContractService.new(network_id: network_id)
        .get_claimed_events(wallet_address)

      # loop through each claimed_event and inside loop through each claim until the claimed_event amount is same as the sum of the claism amounts
      # then update the claim to claimed = true and save transaction_hash and receiver_address
      claimed_events.each do |event|
        claim_amount = 0
        claims.each do |claim|
          if claim.claimed
            next
          end

          claim_amount += claim.amount

          if claim_amount > event[:amount]
            break
          end

          claim.update(claimed: true, transaction_hash: event[:transaction_hash], receiver_address: event[:receiver])
        end
      end
    end

  end
end
