namespace :activities do
  desc "fetches latest activities and inserts them into db"
  task :import, [:symbol] => :environment do |task, args|

    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      actions = Rails.cache.fetch("api:actions:#{network_id}", expires_in: 24.hours) do
        Rpc::PredictionMarketContractService.new(network_id: network_id).get_action_events
      end

      activity_tx_ids = Activity.where(network_id: network_id).pluck(:tx_id).uniq

      # fetching activity txs from db and making diff
      actions.reject { |action| activity_tx_ids.include?(action[:tx_id]) }.each do |action|
        Activity.create_from_prediction_market_action(network_id, action)
      end
    end
  end
end
