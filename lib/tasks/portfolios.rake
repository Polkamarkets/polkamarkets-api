namespace :portfolios do
  desc "refreshes eth cache of portfolios"
  task :refresh_cache, [:hours] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      hours = args[:hours].present? ? args[:hours].to_i : 30

      # fetching unique users from the last X hours
      eth_addresses = Activity
        .where(network_id: network_id)
        .where("timestamp > ?", DateTime.now - hours.hours)
        .pluck(:address)
        .map(&:downcase)
        .uniq
      eth_addresses.each do |eth_address|
        portfolio = Portfolio.find_or_create_by!(eth_address: eth_address.downcase, network_id: network_id)
        portfolio.refresh_cache!(queue: 'low')
      end
    end
  end
end
