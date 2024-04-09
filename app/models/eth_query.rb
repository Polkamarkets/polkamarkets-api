class EthQuery < ApplicationRecord
  validates_presence_of :contract_name, :network_id, :event
  validates_uniqueness_of :filter, scope: %i[network_id contract_name event]

  has_and_belongs_to_many :eth_events
end
