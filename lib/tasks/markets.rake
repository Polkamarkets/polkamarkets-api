namespace :markets do
  desc "checks for new markets and creates them"
  task :check_new_markets, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      # triggering a dummy events query for caching update purposes
      Bepro::PredictionMarketContractService.new(network_id: network_id).get_events(event_name: 'MarketCreated')

      eth_market_ids = Bepro::PredictionMarketContractService.new(network_id: network_id).get_all_market_ids.map(&:to_i)
      db_market_ids = Market.where(network_id: network_id).pluck(:eth_market_id)

      (eth_market_ids - db_market_ids).each do |market_id|
        begin
          Market.create_from_eth_market_id!(network_id, market_id)
        rescue => e
          Sentry.capture_exception(e)
        end
      end
    end
  end

  desc "checks for markets that are scheduled to be published"
  task :check_scheduled_markets, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      # fetching markets scheduled to be published
      markets = Market.where(
        network_id: network_id,
        publish_status: :draft,
      ).where(
        'scheduled_at < ?', Time.now
      )

      # publishing markets
      markets.each do |market|
        begin
          if market.schedule_tries >= Market::MAX_SCHEDULE_TRIES
            # resetting schedule status
            market.update(schedule_tries: 0, scheduled_at: nil)
            Sentry.capture_message("Market #{market.id} reached max schedule tries")
            next
          end

          market.create_and_publish!
        rescue => e
          market.update(schedule_tries: market.schedule_tries + 1)

          Sentry.capture_exception(e)
        end
      end
    end
  end

  task :check_publishing_markets, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      # fetching markets scheduled to be published
      markets = Market.where(
        network_id: network_id,
        publish_status: :pending,
      ).where(
        'updated_at < ?', Time.now - 1.hour
      )

      # resetting markets to draft
      markets.each do |market|
        Sentry.capture_message("Market #{market.id} reset to draft")
        market.update(publish_status: :draft)
      end
    end
  end

  task :check_expiring_markets, [:symbol] => :environment do |task, args|
    # fetching markets expiring in the next 24 hours
    markets = Market.where(
      'expires_at > ? AND expires_at < ?',
      Time.now,
      Time.now + 24.hours
    )

    # posting a message on discord
    markets.each do |market|
      # ignores job if market already posted
      next if Rails.cache.read("discord:market_expiring:#{market.network_id}:#{market.eth_market_id}")

      Discord::PublishMarketExpiringWorker.perform_async(market.id)
    end
  end

  task :check_arbitration_requested_markets, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      arbitration_network_id = Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :arbitration_network_id)
      arbitration_contract_address = Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :arbitration_proxy_contract_address).to_s.downcase

      next if arbitration_network_id.blank? || arbitration_contract_address.blank?

      markets = Market.where(network_id: network_id).all

      arbitration_requests =
        Bepro::ArbitrationContractService.new(network_id: arbitration_network_id)
          .arbitration_requests

      arbitration_requests.each do |arbitration_request|
        # matching market question_id and arbitration_request question_id
        market = markets.find { |market| market.question_id == arbitration_request[:question_id] }
        next if market.blank?

        Discord::PublishArbitrationRequestedWorker.perform_async(market.id, arbitration_request[:max_previous])
      end
    end
  end

  desc "updates markets og images"
  task :update_og_images, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      # fetching latest actions
      Market.includes(:tournament_groups).where(og_image_url: nil).each do |market|
        next if market.og_theme.blank? || !market.published?

        # updating og image
        market.update_og_image
      end
    end
  end

  desc "refreshes eth cache of markets"
  task :refresh_cache, [:symbol] => :environment do |task, args|
    Market.all.each { |m| m.refresh_cache!(queue: 'low') if m.should_refresh_cache? }
  end

  desc "refreshes serializer cache of markets"
  task :refresh_serializer_cache, [:symbol] => :environment do |task, args|
    Market.all.each { |m| m.refresh_serializer_cache! if m.published? }
  end

  desc "refreshes markets news"
  task :refresh_news, [:symbol] => :environment do |task, args|
    Market.all.each { |m| m.refresh_news!(queue: 'low') }
  end

  desc "refreshes markets votes"
  task :refresh_votes, [:symbol] => :environment do |task, args|
    Market.all.each { |m| Cache::MarketVotesWorker.set(queue: 'low').perform_async(m.id) }
  end

  desc "features markets published in the last 24 hours"
  task :unfeature_markets, [:symbol] => :environment do |task, args|
    # unfeaturing all closed markets
    Market.where(featured: true).each do |market|
      next if market.expires_at > DateTime.now && !market.resolved?

      market.update(featured: false)
    end
  end
end
