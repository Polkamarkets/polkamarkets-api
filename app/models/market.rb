class Market < ApplicationRecord
  include NetworkHelper
  include Immutable
  extend FriendlyId
  friendly_id :title, use: :slugged

  validates_presence_of :title, :category, :expires_at, :network_id
  validates_uniqueness_of :eth_market_id, scope: :network_id

  after_destroy :destroy_cache!

  has_many :outcomes, -> { order('eth_market_id ASC, created_at ASC') }, class_name: "MarketOutcome", dependent: :destroy, inverse_of: :market

  has_many :comments, -> { includes :user }, dependent: :destroy

  has_one_attached :image

  validates :outcomes, length: { minimum: 2 } # currently supporting only binary markets

  accepts_nested_attributes_for :outcomes

  scope :published, -> { where('published_at < ?', DateTime.now).where.not(eth_market_id: nil) }
  scope :open, -> { published.where('expires_at > ?', DateTime.now) }
  scope :resolved, -> { published.where('expires_at < ?', DateTime.now) }

  IMMUTABLE_FIELDS = [:title]

  def self.find_by_slug_or_eth_market_id!(id_or_slug, network_id = nil)
    Market.find_by(slug: id_or_slug) ||
      Market.find_by!(eth_market_id: id_or_slug, network_id: network_id)
  end

  def self.create_from_eth_market_id!(network_id, eth_market_id)
    raise "Market #{eth_market_id} is already created" if Market.where(network_id: network_id, eth_market_id: eth_market_id).exists?

    eth_data =
      Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:data", force: true) do
        Bepro::PredictionMarketContractService.new(network_id: network_id).get_market(eth_market_id)
      end

    # invalid market
    raise "Market #{eth_market_id} does not exist" if eth_data[:outcomes].blank?

    market = Market.new(
      title: eth_data[:title],
      description: eth_data[:description],
      category: eth_data[:category],
      subcategory: eth_data[:subcategory],
      eth_market_id: eth_market_id,
      expires_at: eth_data[:expires_at],
      published_at: DateTime.now,
      image_url: IpfsService.image_url_from_hash(eth_data[:image_hash]),
      network_id: network_id
    )
    eth_data[:outcomes].each_with_index do |outcome, i|
      image_hash = eth_data[:outcomes_image_hashes].present? ? eth_data[:outcomes_image_hashes][i] : nil
      market.outcomes << MarketOutcome.new(
        title: outcome[:title],
        eth_market_id: outcome[:id],
        image_url: image_hash ? IpfsService.image_url_from_hash(image_hash) : nil
      )
    end

    market.save!

    # updating banner image asynchrounously
    MarketBannerWorker.perform_async(market.id)

    # triggering workers to upgrade cache data
    market.refresh_cache!(queue: 'critical')
    market.refresh_news!(queue: 'critical')

    # triggering discord bot 5 minutes later (so it allows banner image to be updated)
    Discord::PublishMarketCreatedWorker.perform_in(5.minutes, market.id)

    market
  end

  def eth_data(refresh: false)
    return nil if eth_market_id.blank?

    return @eth_data if @eth_data.present? && !refresh

    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:data", force: refresh) do
      @eth_data = Bepro::PredictionMarketContractService.new(network_id: network_id).get_market(eth_market_id)
    end
  end

  def open?
    !closed?
  end

  def closed?
    return false if eth_data.blank?

    eth_data[:expires_at] < DateTime.now
  end

  def resolved?
    closed? && eth_data[:state] == 'resolved'
  end

  def expires_at
    return self["expires_at"] if eth_data.blank?

    eth_data[:expires_at]
  end

  def resolution_source
    return nil if eth_data.blank?

    eth_data[:resolution_source]
  end

  def state
    return nil if eth_data.blank?

    state = eth_data[:state]

    # market already closed, manually sending closed
    return 'closed' if eth_data[:state] == 'open' && closed?

    state
  end

  def resolved_outcome_id
    return nil if eth_data.blank?

    eth_data[:resolved_outcome_id]
  end

  def question_id
    return nil if eth_data.blank?

    eth_data[:question_id]
  end

  def fee
    return nil if eth_data.blank?

    eth_data[:fee]
  end

  def treasury_fee
    return nil if eth_data.blank?

    eth_data[:treasury_fee]
  end

  def treasury
    return nil if eth_data.blank?

    eth_data[:treasury]
  end

  def resolved_outcome
    return unless resolved?

    outcomes.find_by(eth_market_id: resolved_outcome_id)
  end

  def liquidity
    return nil if eth_data.blank?

    eth_data[:liquidity]
  end

  def liquidity_eur
    return nil if eth_data.blank?

    liquidity * token_rate
  end

  def shares
    return nil if eth_data.blank?

    eth_data[:shares]
  end

  def voided
    return nil if eth_data.blank?

    eth_data[:voided]
  end

  def liquidity_price
    prices[:liquidity_price]
  end

  def resolved_at(refresh: false)
    return -1 if eth_market_id.blank? || !resolved?

    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:resolved_at", force: refresh) do
      Bepro::PredictionMarketContractService.new(network_id: network_id).get_market_resolved_at(eth_market_id)
    end
  end

  def prices(refresh: false)
    return {} if eth_market_id.blank?

    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:prices", force: refresh) do
      Bepro::PredictionMarketContractService.new(network_id: network_id).get_market_prices(eth_market_id)
    end
  end

  def outcome_prices(timeframe, candles: 12, refresh: false, end_at_resolved_at: false)
    return {} if eth_market_id.blank?

    market_prices =
      Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:events:price", force: refresh) do
        Bepro::PredictionMarketContractService.new(network_id: network_id).get_price_events(eth_market_id)
      end

    market_prices.group_by { |price| price[:outcome_id] }.map do |outcome_id, prices|
      # if market is resolved, we only want to show prices until it was resolved
      end_timestamp = (resolved? && end_at_resolved_at) ? resolved_at : nil

      chart_data_service = ChartDataService.new(prices, :price)
      # returning in hash form
      [outcome_id, chart_data_service.chart_data_for(timeframe, end_timestamp)]
    end.to_h
  end

  def liquidity_prices(timeframe, candles: 12, refresh: false)
    return [] if eth_market_id.blank?

    liquidity_prices =
      Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:events:liquidity", force: refresh) do
        Bepro::PredictionMarketContractService.new(network_id: network_id).get_liquidity_events(eth_market_id)
      end

    chart_data_service = ChartDataService.new(liquidity_prices, :price)
    chart_data_service.chart_data_for(timeframe)
  end

  def action_events(address: nil, refresh: false)
    return [] if eth_market_id.blank?

    # TODO: review caching both globally and locally

    market_actions =
      Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:actions", force: refresh) do
        Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events(market_id: eth_market_id)
      end

    market_actions.select do |action|
      address.blank? || action[:address].downcase == address.downcase
    end
  end

  def volume
    action_events
      .select { |a| ['buy', 'sell'].include?(a[:action]) }
      .sum { |a| a[:value] }
  end

  def volume_eur
    # no need to fetch token value if volume is 0
    return 0 if volume == 0

    volume * token_rate
  end

  def token_rate
    TokenRatesService.new.get_token_rate_from_address(token[:address], network_id, 'eur')
  end

  def token_rate_at(timestamp)
    TokenRatesService.new.get_token_rate_from_address_at(token[:address], network_id, 'eur', timestamp)
  end

  def keywords(refresh: false)
    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:keywords", force: refresh) do
      title_keywords = TextRazorService.new.get_entities(title).sort_by do |e|
        # prioritizing custom dictionary
        e['customEntityId'].present? ? 99 : e['confidenceScore']
      end.reverse
      title_keywords.select! do |entity|
        entity['customEntityId'].present? || entity['confidenceScore'] >= 1
      end

      return [category, subcategory] if title_keywords.count == 0

      title_keywords.map { |entity| entity['entityEnglishId'].presence || entity['matchedText'] }.uniq[0..2]
    end
  end

  def news(refresh: false)
    return [] if eth_market_id.blank?

    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:news", force: refresh) do
      # only fetching news if market is not resolved or expired over 7 days ago
      return [] if resolved? || expires_at < 7.days.ago

      begin
        GnewsService.new.get_latest_news(keywords)
      rescue => exception
        # 429 http status requests should be raised and retried
        raise exception if exception.message.include?('429')

        # service should be non-blocking, reporting to sentry and returning empty array
        Sentry.capture_exception(exception)
        []
      end
    end
  end

  def feed(refresh: false)
    return [] if eth_market_id.blank?

    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:feed", force: refresh) do
      FeedService.new(market_id: eth_market_id, network_id: network_id).feed_actions
    end
  end

  def should_refresh_cache?
    # TODO: figure out caching system from closed (and unresolved) markets
    !(resolved? && resolved_at < 1.day.ago.to_i)
  end

  def destroy_cache!
    Cache::MarketCacheSerializerDeleteWorker.new.perform(id)
    Cache::MarketCacheEthDeleteWorker.new.perform(id)
  end

  def refresh_cache!(queue: 'default')
    # triggering a refresh for all serialized data
    Cache::MarketCacheSerializerDeleteWorker.set(queue: queue).perform_async(id)
    Cache::MarketEthDataWorker.set(queue: queue).perform_async(id)
    Cache::MarketOutcomePricesWorker.set(queue: queue).perform_async(id)
    Cache::MarketActionEventsWorker.set(queue: queue).perform_async(id)
    Cache::MarketPricesWorker.set(queue: queue).perform_async(id)
    Cache::MarketLiquidityPricesWorker.set(queue: queue).perform_async(id)
    Cache::MarketQuestionDataWorker.set(queue: queue).perform_async(id)
    Cache::MarketVotesWorker.set(queue: queue).perform_async(id)
    Cache::MarketFeedWorker.set(queue: queue).perform_async(id)
  end

  def refresh_cache_sync!
    Cache::MarketCacheSerializerDeleteWorker.new.perform(id)
    Cache::MarketEthDataWorker.new.perform(id)
    Cache::MarketOutcomePricesWorker.new.perform(id)
    Cache::MarketActionEventsWorker.new.perform(id)
    Cache::MarketPricesWorker.new.perform(id)
    Cache::MarketLiquidityPricesWorker.new.perform(id)
    Cache::MarketQuestionDataWorker.new.perform(id)
    Cache::MarketVotesWorker.new.perform(id)
    Cache::MarketFeedWorker.new.perform(id)

    true
  end

  def refresh_news!(queue: 'default')
    Cache::MarketNewsWorker.set(queue: queue).perform_async(id)
  end

  def image_url
    # return Rails.application.routes.url_helpers.rails_blob_url(image) if image.present?

    return if self['image_url'].blank?

    # TODO: save image_hash only and concatenate with ipfs hosting provider
    image_hash = self['image_url'].split('/').last

    IpfsService.image_url_from_hash(image_hash)
  end

  def update_banner_image
    banner_image_url = BannerbearService.new.create_banner_image(self)
    self.update(banner_url: banner_image_url)
  end

  # realitio data
  def question_data(refresh: false)
    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:question", force: refresh) do
      question_data = Bepro::RealitioErc20ContractService.new(network_id: network_id).get_question(question_id)

      # fetching market dispute id and pending arbitration requests
      arbitration_network_id = Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :arbitration_network_id)
      arbitration_contract_address = Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :arbitration_proxy_contract_address).to_s.downcase

      next question_data.merge(
        dispute_id: nil,
        is_pending_arbitration_request: false
      ) if arbitration_network_id.blank? || question_data[:arbitrator].downcase != arbitration_contract_address

      dispute_id = question_data[:is_pending_arbitration] ?
        nil :
        Bepro::ArbitrationContractService.new(network_id: arbitration_network_id).dispute_id(question_id)

      next question_data.merge(
        dispute_id: dispute_id,
        is_pending_arbitration_request: false
      ) if dispute_id.present? || question_data[:is_pending_arbitration]

      arbitration_requests = Bepro::ArbitrationContractService.new(network_id: arbitration_network_id).arbitration_requests(question_id)

      arbitration_requests_rejected = Bepro::ArbitrationProxyContractService.new(network_id: network_id).arbitration_requests_rejected(question_id)

      question_data.merge(
        dispute_id: dispute_id,
        is_pending_arbitration_request: arbitration_requests.count > arbitration_requests_rejected.count
      )
    end
  end

  # vote data
  def votes(refresh: false)
    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:votes", force: refresh) do
      Bepro::VotingContractService.new(network_id: network_id).get_votes(eth_market_id)
    end
  end

  def votes_delta
    votes[:up] - votes[:down]
  end

  def token(refresh: false)
    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:token", force: refresh) do
      token_address = eth_data[:token_address]
      return if token_address.blank?

      token = Bepro::Erc20ContractService.new(network_id: network_id, contract_address: token_address).token_info
      wrapped = token_address.downcase == network_weth_address(network_id).downcase

      # TODO: configurable image urls
      token.merge(
        image_url: "https://dl.dropboxusercontent.com/s/zev7x0zcy0lu8x6/token.png?dl=0",
        wrapped: wrapped
      )
    end
  end

  def users
    action_events.map { |action| action[:address] }.uniq.count
  end

  def polkamarkets_web_url
    "#{Rails.application.config_for(:polkamarkets).web_url}/markets/#{slug}"
  end
end
