class Claim < ApplicationRecord
  validates_presence_of :network_id, :wallet_address, :amount, :claim_type, :token_address
  validates :claim_type, inclusion: { in: %w[tournament streak] }
  validates_uniqueness_of :wallet_address, scope: %i[network_id claim_type data]

  def self.get_wallet_address_preferred_token(network_id, wallet_address, token_addresses)
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
