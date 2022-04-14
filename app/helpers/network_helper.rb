
module NetworkHelper
  def network_name(network_id)
    network = Rails.application.config_for(:networks).find { |name, id| id == network_id }
    network ? network.first.to_s.capitalize : 'Unknown'
  end
end
