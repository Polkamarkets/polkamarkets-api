
module NetworkHelper
  def network_name(network_id)
    network = Rails.application.config_for(:networks).find { |name, id| id == network_id }
    network ? network.first.to_s.capitalize : 'Unknown'
  end

  def network_actions(network_id)
    Rails.cache.fetch("actions:#{network_id}", expires_in: 24.hours) do
      Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events
    end
  end

  def network_bonds(network_id)
    Rails.cache.fetch("actions:#{network_id}", expires_in: 24.hours) do
      Bepro::PredictionMarketContractService.new(network_id: network_id).get_bond_events
    end
  end
end
