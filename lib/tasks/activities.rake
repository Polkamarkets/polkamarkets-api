namespace :activities do
  desc "fetches latest activities and inserts them into db"
  task :import, [:symbol] => :environment do |task, args|

    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      actions = Rails.cache.fetch("api:actions:#{network_id}", expires_in: 24.hours) do
        Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events
      end

      activity_txs = {}
      Activity.where(network_id: network_id).pluck(:tx_id, :log_index).each do |tx_id, log_index|
        activity_txs[tx_id] ||= {}
        activity_txs[tx_id][log_index] = true
      end

      # fetching activity txs from db and making diff
      actions.each do |action|
        next if activity_txs.dig(action[:tx_id], action[:log_index])

        if activity_txs.dig(action[:tx_id], nil)
          # legacy activity, updating log index
          activity = Activity.find_by(
            network_id: network_id,
            tx_id: action[:tx_id],
            address: action[:address],
            action: action[:action],
            market_id: action[:market_id],
            outcome_id: action[:outcome_id],
            shares: action[:shares],
            amount: action[:value],
            log_index: nil
          )
          activity.update(log_index: action[:log_index]) if activity
        else
          Activity.create_or_update_from_prediction_market_action(network_id, action)
        end
      end
    end
  end
end
