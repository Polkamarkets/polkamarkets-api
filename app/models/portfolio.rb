class Portfolio < ApplicationRecord
  validates_presence_of :eth_address

  before_validation :normalize_eth_address

  validate :eth_address_validation

  def normalize_eth_address
    # setting default to downcase to avoid case duplicates
    self.eth_address = self.eth_address.downcase
  end

  def eth_address_validation
    unless eth_address.match(/0[x,X][a-fA-F0-9]{40}$/)
      errors.add(:eth_address, 'Invalid ETH address')
    end
  end
end
