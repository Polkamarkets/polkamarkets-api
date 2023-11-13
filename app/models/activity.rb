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
    :block_number

  def self.create_from_prediction_market_action(network_id, action)
    activity = Activity.find_or_create_by(
      network_id: network_id,
      tx_id: action[:tx_id],
      action: action[:action]
    )

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
      block_number: action[:block_number]
    )

    activity
  end
end
