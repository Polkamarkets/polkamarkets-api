class ClaimService
  def create_claim(network_id, wallet_address, amount, token_address, claim_type, data)
    Claim.create!(
      network_id: network_id,
      wallet_address: wallet_address,
      amount: amount,
      token_address: token_address,
      claim_type: claim_type,
      data: data
    )
  end

  def get_wallet_address_preferred_token(network_id, wallet_address, token_addresses)
    max = 0.0;
    max_token = token_addresses.first

    return max_token if token_addresses.length == 1

    token_addresses.each do |token, address|
        balance = Bepro::Erc20ContractService.new(network_id: network_id, contract_address: address).balance_of(wallet_address)
        if balance > max
          max = balance
          max_token = token
        end
    end

    max_token
  end
end
