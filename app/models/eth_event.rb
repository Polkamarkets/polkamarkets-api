class EthEvent < ApplicationRecord
  validates_presence_of :contract_name,
    :network_id,
    :event,
    :address,
    :block_number,
    :log_index,
    :transaction_hash

  validates_uniqueness_of :transaction_hash, scope: [:network_id, :log_index]

  has_and_belongs_to_many :eth_queries

  def serialize_as_eth_log
    {
      address: address,
      blockHash: block_hash,
      blockNumber: block_number,
      logIndex: log_index,
      removed: removed,
      transactionHash: transaction_hash,
      transactionIndex: transaction_index,
      signature: signature,
      returnValues: data,
      raw: raw_data,
      event: event
    }.deep_stringify_keys
  end
end
