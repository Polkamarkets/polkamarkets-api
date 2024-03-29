namespace :portfolios do
  desc "refreshes eth cache of portfolios"
  task :refresh_cache, [:days] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      days = args[:days].present? ? args[:days].to_i : 30

      # fetching unique users from the last X days
      eth_addresses = Activity
        .where(network_id: network_id)
        .where("timestamp > ?", DateTime.now - days.days)
        .pluck(:address)
        .map(&:downcase)
        .uniq
      eth_addresses.each do |eth_address|
        portfolio = Portfolio.find_or_create_by!(eth_address: eth_address.downcase, network_id: network_id)
        portfolio.refresh_cache!(queue: 'low')
      end
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
