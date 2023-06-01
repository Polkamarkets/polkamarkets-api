class Tournament < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  validates_presence_of :title, :description, :network_id

  # many to many relationship with markets
  has_and_belongs_to_many :markets

  validate :markets_network_id_validation

  def markets_network_id_validation
    markets.each do |market|
      errors.add(:markets, 'network id is not valid') unless market.network_id == network_id
    end
  end
end
