class Activity < ApplicationRecord
  validates_uniqueness_of :log_index, scope: [:action, :network_id, :tx_id], allow_nil: true

  validates_presence_of :network_id,
    :timestamp,
    :address,
    :action,
    :shares,
    :amount,
    :market_id,
    :outcome_id,
    :tx_id,
    :block_number,
    :token_address

  def self.create_or_update_from_prediction_market_action(network_id, action)
    activity = Activity.find_or_initialize_by(
      network_id: network_id,
      tx_id: action[:tx_id],
      log_index: action[:log_index]
    )

    # token address not on action, fetching from eth_data from market model
    market = Market.find_or_initialize_by(network_id: network_id, eth_market_id: action[:market_id])

    activity.update(
      network_id: network_id,
      timestamp: Time.at(action[:timestamp]).to_datetime,
      address: action[:address],
      action: action[:action],
      shares: action[:shares],
      amount: action[:value],
      market_id: action[:market_id],
      outcome_id: action[:outcome_id],
      tx_id: action[:tx_id],
      block_number: action[:block_number],
      token_address: market.eth_data[:token_address],
      log_index: action[:log_index]
    )

    activity
  end

  def self.max_block_number_by_network_id(network_id)
    # TODO: change block_number to integer
    where(network_id: network_id).maximum('CAST(block_number AS INTEGER)').to_i
  end
end
