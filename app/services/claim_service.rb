class ClaimService
  def create_claim(network_id, wallet_address, amount, claim_type, data)
    Claim.create!(
      network_id: network_id,
      wallet_address: wallet_address,
      amount: amount,
      claim_type: claim_type,
      data: data
      )
  end
end
