class Activity < ApplicationRecord
  validates_uniqueness_of :tx_id, scope: [:action, :network_id]

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

  def self.create_from_prediction_market_action(network_id, action)
    activity = Activity.find_or_create_by(
      network_id: network_id,
      tx_id: action[:tx_id],
      action: action[:action]
    )

    # token address not on action, emulating a market model and fetching from eth_data
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
      token_address: market.eth_data[:token_address]
    )

    activity
  end
end
