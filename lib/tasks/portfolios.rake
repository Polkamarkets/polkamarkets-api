namespace :portfolios do
  desc "refreshes eth cache of portfolios"
  task :refresh_cache, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      bepro = Bepro::PredictionMarketContractService.new(network_id: network_id)

      # fetching unique users
      actions = bepro.get_action_events
      # filtering by actions from the last day
      actions.select! { |a| a[:timestamp] > (DateTime.now - 1.day).to_i }
      eth_addresses = actions.map { |a| a[:address].downcase }.uniq
      Portfolio.where(eth_address: eth_addresses, network_id: network_id).each { |p| p.refresh_cache! }
    end
  end

  task :monitor_overflow_status, [:symbol] => :environment do |task, args|
    return unless Rails.application.config_for(:ethereum).network_ids.include?("1285")

    bepro = Bepro::PredictionMarketContractService.new(network_id: 1285)

    # fetching unique user/market pairs
    actions = bepro.get_action_events
    # filtering by actions from the last 2 days
    actions.select! { |a| a[:timestamp] > (DateTime.now - 2.days).to_i }
    lookups = actions.map { |a| { user: a[:address], market_id: a[:market_id] } }.uniq

    lookups.each do |lookup|
      begin
        # looking for revert SafeMath: subtraction overflow error
        bepro.call(method: 'getUserClaimableFees', args: [lookup[:market_id], lookup[:user]])
      rescue => e
        Sentry.capture_message("SafeMath: subtraction overflow :: User #{lookup[:user]}, Market #{lookup[:market_id]} - #{e.message}") if (e.message.include?('SafeMath'))
      end
    end
  end
end
