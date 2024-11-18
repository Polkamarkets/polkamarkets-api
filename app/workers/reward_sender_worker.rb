class RewardSenderWorker
  include Sidekiq::Worker

  def perform
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      # Fetch data from claims table and use admin account to update RewardsDistributor smart contract
      claims = Claim.where(recorded_at: nil, network_id: network_id)
      users = claims.map(&:wallet_address).uniq

      users.each do |user|
        # fetching all user claims and calculating the total amount by token_address
        user_claims = claims.where(wallet_address: user)
        total_amount_by_token = user_claims.group(:token_address).sum(:amount)

        # updating the RewardsDistributor smart contract with the total amount
        total_amount_by_token.each do |token_address, amount|
          Bepro::RewardsDistributorContractService.new(
            network_id: claim.network_id
          ).set_claim_amount(claim.wallet_address, claim.amount, claim.token_address)

          Claim.where(
            wallet_address: user,
            token_address: token_address,
            network_id: network_id,
            recorded_at: nil
          ).update_all(recorded_at: Time.current)
        end
      end
    end
  end
end
