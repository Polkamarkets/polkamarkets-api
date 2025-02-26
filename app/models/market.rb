class Market < ApplicationRecord
  include NetworkHelper
  include BigNumberHelper
  include Reportable
  include Likeable
  include Imageable
  include OgImageable
  extend FriendlyId
  friendly_id :title, use: :slugged

  validates_presence_of :title, :category, :expires_at, :network_id
  validates_uniqueness_of :eth_market_id, scope: :network_id, if: -> { eth_market_id.present? }

  after_destroy :destroy_cache!

  has_many :outcomes, -> { order('eth_market_id ASC, created_at ASC') }, class_name: "MarketOutcome", dependent: :destroy, inverse_of: :market

  accepts_nested_attributes_for :outcomes

  has_many :comments, -> { includes :user }, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy

  has_one_attached :image

  has_and_belongs_to_many :tournaments
  has_many :tournament_groups, through: :tournaments

  validates :outcomes, length: { minimum: 2 } # currently supporting only binary markets

  accepts_nested_attributes_for :outcomes

  enum publish_status: {
    draft: 0,
    pending: 1,
    published: 2,
  }

  has_paper_trail

  scope :published, -> { where('published_at < ?', DateTime.now).where.not(eth_market_id: nil) }
  scope :unpublished, -> { where('published_at is NULL OR published_at > ?', DateTime.now).or(where(eth_market_id: nil)) }
  scope :open, -> { published.where('expires_at > ?', DateTime.now) }
  scope :resolved, -> { published.where('expires_at < ?', DateTime.now) }

  IMAGEABLE_FIELDS = [:image_url, :banner_url].freeze
  EDITABLE_FIELDS = %i[title description resolution_source resolution_title].freeze
  MAX_SCHEDULE_TRIES = 3.freeze
  OG_IMAGEABLE_PATH = 'questions'
  OG_IMAGEABLE_FIELDS = %i[title].freeze

  def self.all_voided_market_ids
    Rails.cache.fetch('markets:voided', expires_in: 5.minutes) do
      Market.all.group_by(&:network_id).map do |network_id, markets|
        market_ids = markets.select(&:voided).map do |market|
          market.eth_market_id
        end

        [network_id, market_ids]
      end.to_h
    end
  end

  def self.find_by_slug_or_eth_market_id!(id_or_slug, network_id = nil)
    Market.find_by(slug: id_or_slug) ||
      Market.find_by!(eth_market_id: id_or_slug, network_id: network_id)
  end

  def self.create_from_eth_market_id!(network_id, eth_market_id)
    raise "eth_market_id is required" if eth_market_id.blank?

    market = Market.find_by(network_id: network_id, eth_market_id: eth_market_id)

    return market if market.present?

    eth_data =
      Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:data", force: true) do
        Bepro::PredictionMarketContractService.new(network_id: network_id).get_market(eth_market_id)
      end

    # invalid market
    raise "Market #{eth_market_id} does not exist" if eth_data[:outcomes].blank?

    # checking if market is already in draft in the database
    # first checking slug metadata
    market = Market.find_by(slug: eth_data[:draft_slug], eth_market_id: nil) if eth_data[:draft_slug].present?
    # also checking title
    market ||= Market.find_by(title: eth_data[:title], eth_market_id: nil, network_id: network_id)

    if market.present?
      market.update!(
        title: eth_data[:title],
        eth_market_id: eth_market_id,
        description: eth_data[:description],
        category: eth_data[:category],
        subcategory: eth_data[:subcategory],
        expires_at: eth_data[:expires_at],
        published_at: DateTime.now,
        image_url: IpfsService.image_url_from_hash(eth_data[:image_hash]),
        network_id: network_id,
        publish_status: :published
      )
      eth_data[:outcomes].each_with_index do |outcome, i|
        image_hash = eth_data[:outcomes_image_hashes].present? ? eth_data[:outcomes_image_hashes][i] : nil
        market.outcomes[i].update!(
          title: outcome[:title],
          eth_market_id: outcome[:id],
          image_url: image_hash ? IpfsService.image_url_from_hash(image_hash) : nil
        )
      end
    else
      market = Market.new(
        title: eth_data[:title],
        description: eth_data[:description],
        category: eth_data[:category],
        subcategory: eth_data[:subcategory],
        eth_market_id: eth_market_id,
        expires_at: eth_data[:expires_at],
        published_at: DateTime.now,
        image_url: IpfsService.image_url_from_hash(eth_data[:image_hash]),
        network_id: network_id,
        publish_status: :published
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
    end

    # triggering workers to upgrade cache data
    market.refresh_cache!(queue: 'critical')

    market
  end

  def scheduled_at_validation
    return if scheduled_at.blank?
    return if expires_at.blank?
    return if published?

    errors.add(:scheduled_at, 'cannot be in the past') if scheduled_at < DateTime.now
    errors.add(:scheduled_at, 'cannot be after market expiration') if scheduled_at > expires_at
  end

  def eth_data(refresh: false)
    return nil if eth_market_id.blank?

    return @eth_data if @eth_data.present? && !refresh

    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:data", force: refresh) do
      @eth_data = Bepro::PredictionMarketContractService.new(network_id: network_id).get_market(eth_market_id)
    end
  end

  def published?
    published_at.present? && published_at < DateTime.now && eth_market_id.present?
  end

  def open?
    !closed?
  end

  def closed?
    return false if eth_data.blank?

    eth_data[:state] == 'resolved' || eth_data[:expires_at] < DateTime.now
  end

  def resolved?
    closed? && eth_data[:state] == 'resolved'
  end

  def expires_at
    return self["expires_at"] if eth_data.blank?

    eth_data[:expires_at]
  end

  def created_at
    return published_at if published?

    self["created_at"]
  end

  def scheduled_at
    return nil if published?

    self["scheduled_at"]
  end

  def resolution_source
    return self["resolution_source"] if self["resolution_source"].present? || eth_data.blank?

    eth_data[:resolution_source]
  end

  def resolution_title
    return self["resolution_title"] if self["resolution_title"].present? || eth_data.blank?

    eth_data[:resolution_title]
  end

  def topics
    return self["topics"] if self["topics"].present? || eth_data.blank?

    eth_data[:topics] || []
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
    return self[:draft_fee] if eth_data.blank?

    eth_data[:fee]
  end

  def treasury_fee
    return self[:draft_treasury_fee] if eth_data.blank?

    eth_data[:treasury_fee]
  end

  def treasury
    return self[:draft_treasury] if eth_data.blank?

    eth_data[:treasury]
  end

  def resolved_outcome
    return unless resolved?

    outcomes.find_by(eth_market_id: resolved_outcome_id)
  end

  def liquidity
    return self[:draft_liquidity] if eth_data.blank?

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

  def outcome_current_prices
    eth_data[:outcomes].map do |outcome|
      [outcome[:id], outcome[:price]]
    end.to_h
  end

  def prices(refresh: false)
    return {} if eth_market_id.blank?

    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:prices", force: refresh) do
      Bepro::PredictionMarketContractService.new(network_id: network_id).get_market_prices(eth_market_id)
    end
  end

  def market_prices(refresh: false)
    cache_key = "markets:network_#{network_id}:#{eth_market_id}:events:prices"

    prices = Rails.cache.read(cache_key) || []

    if refresh || prices.blank?
      # fetching latest prices starting from the last price block number
      last_block_number = prices.max_by { |price| price[:block_number] }&.dig(:block_number) || 0

      new_prices =
        Bepro::PredictionMarketContractService.new(network_id: network_id).get_price_events(
          eth_market_id,
          from_block: last_block_number
        )

      prices += new_prices
      prices = prices.uniq.sort_by { |price| price[:timestamp] }

      Rails.cache.write(cache_key, prices)
    end

    prices
  end

  def outcome_prices(timeframe, candles: 12, refresh: false, end_at_resolved_at: false)
    return {} if eth_market_id.blank?

    return @outcome_prices[timeframe] if !refresh && @outcome_prices.present? && @outcome_prices[timeframe].present?

    @outcome_prices ||= {}
    @outcome_prices[timeframe] =
      market_prices(refresh: refresh).group_by { |price| price[:outcome_id] }.map do |outcome_id, prices|
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

  def action_events(address: nil, refresh: false, from_block: nil)
    return [] if eth_market_id.blank?

    if from_block.present?
      return Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events(
        market_id: eth_market_id,
        from_block: from_block
      )
    end

    cache_key = "markets:network_#{network_id}:#{eth_market_id}:actions"

    actions = Rails.cache.read(cache_key) || []

    if refresh || actions.blank?
      # fetching latest actions starting from the last action block number
      last_block_number = actions.max_by { |action| action[:block_number] }&.dig(:block_number) || 0

      new_actions =
        Bepro::PredictionMarketContractService.new(network_id: network_id).get_action_events(
          market_id: eth_market_id,
          from_block: last_block_number
        )

      actions += new_actions
      actions = actions.uniq.sort_by { |action| action[:block_number] }

      Rails.cache.write(cache_key, actions)
      GC.start
    end

    actions.select do |action|
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

    FeedService.new(market_id: eth_market_id, network_id: network_id).fetch_feed(refresh: refresh)
  end

  def should_refresh_cache?
    # TODO: figure out caching system from closed (and unresolved) markets
    published? && !(resolved? && resolved_at < 1.day.ago.to_i)
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

  def refresh_prices!(queue: 'default')
    Cache::MarketRefreshPricesWorker.set(queue: queue).perform_async(id)
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

  def refresh_serializer_cache!(queue: 'default')
    Cache::MarketCacheSerializerRefreshWorker.set(queue: queue).perform_async(id)
  end

  def refresh_serializer_cache_sync!
    Cache::MarketCacheSerializerRefreshWorker.new.perform(id)
  end

  def refresh_news!(queue: 'default')
    Cache::MarketNewsWorker.set(queue: queue).perform_async(id)
  end

  def image_url
    return self['image_url'] if self['image_url'].present?

    return IpfsService.image_url_from_hash(image_ipfs_hash) if image_ipfs_hash.present?

    # if there's only image for the first outcome, we use it as image_url
    if outcomes.first.image_url.present? && outcomes[1..-1].all? { |o| o.image_url.blank? }
      return outcomes.first.image_url
    end
  end

  def image_ipfs_hash
    return self[:image_ipfs_hash] if eth_data.blank?

    eth_data[:image_hash]
  end

  def update_banner_image
    banner_image_url = BannerbearService.new.create_banner_image(self)
    self.update(banner_url: banner_image_url) if banner_image_url.present?
  end

  # realitio data
  def question_data(refresh: false)
    return Bepro::RealitioErc20ContractService.default_question_data(timeout: draft_timeout || 0) if question_id.blank?

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
    # TODO: fetch from land
    return nil if eth_data.blank?

    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:token", force: refresh) do
      token_address = eth_data[:token_address]
      return if token_address.blank?

      token = Bepro::Erc20ContractService.new(network_id: network_id, contract_address: token_address).token_info
      wrapped = token_address.downcase == network_weth_address(network_id).downcase

      token.merge(
        wrapped: wrapped
      )
    end
  end

  def users(refresh: false)
    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:users", force: refresh) do
      action_events.map { |action| action[:address] }.uniq.count
    end
  end

  def holders(refresh: false)
    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:holders", force: refresh) do
      holders = {}

      action_events.each do |action|
        holders[action[:outcome_id]] ||= {}
        holders[action[:outcome_id]][action[:address]] ||= 0

        case action[:action]
        when 'buy'
          holders[action[:outcome_id]][action[:address]] += action[:shares]
        when 'sell'
          holders[action[:outcome_id]][action[:address]] -= action[:shares]
        end
      end;

      # filtering shares < 1
      holders.each do |outcome_id, outcome_holders|
        outcome_holders.delete_if { |address, amount| amount < 1 }
      end;

      # sorting holders by amount
      holders.each do |outcome_id, outcome_holders|
        holders[outcome_id] = outcome_holders.sort_by { |address, amount| -amount }.to_h
      end;

      holders
    end
  end

  def update_comments_counter
    self.comments_count = comments.count
    save
  end

  def related_markets(refresh: false)
    return [] if tournaments.blank?

    Rails.cache.fetch("markets:network_#{network_id}:#{eth_market_id}:related_markets", force: refresh) do
      tournaments
        .order(:position)
        .map(&:markets)
        .flatten.uniq
        .select { |market| market.id != id && market.published? }.first(5)
    end
  end

  def admins
    return [] if tournaments.blank?

    tournaments.map(&:admins).flatten.uniq
  end

  def duplicate!
    # creates a draft market with the same outcomes
    new_market = dup

    new_market.title = "#{title} (Copy)"
    new_market.eth_market_id = nil
    new_market.published_at = nil
    new_market.publish_status = :draft
    new_market.scheduled_at = nil

    outcomes.each do |outcome|
      new_market.outcomes << outcome.dup
    end

    new_market.tournament_ids = tournament_ids

    new_market.save!
    new_market
  end

  def prepare_draft_for_market_creation_args
    arbitrator =
      Rails.application.config_for(:ethereum).dig(
        :"network_#{network_id}",
        :arbitration_proxy_contract_address
      ).to_s.downcase.presence || '0x000000000000000000000000000000000000dead'

    tournament_group = tournament_groups.first

    raise "Market has no active tournament group" if tournament_group.blank? || tournament_group.token.blank?

    prediction_market_contract_service = Bepro::PredictionMarketContractService.new(network_id: network_id)

    {
      value: from_integer_to_big_number(draft_liquidity || 1000, 18).to_s,
      closesAt: expires_at.to_i,
      outcomes: outcomes.count,
      token: tournament_group.token[:address],
      distribution: prediction_market_contract_service.calculate_odds_distribution(
        outcomes.map { |outcome| outcome.draft_price.presence || 1.0 / outcomes.count }
      ),
      question: prediction_market_contract_service.generate_question_string(
        title,
        description,
        category,
        subcategory,
        topics,
        resolution_source,
        resolution_title,
        slug,
        outcomes.map(&:title)
      ),
      image: prediction_market_contract_service.generate_image_string(
        image_ipfs_hash,
        outcomes.map(&:image_ipfs_hash)
      ),
      arbitrator: arbitrator,
      fee: "0",
      treasuryFee: "0",
      treasury: draft_treasury || "0x0000000000000000000000000000000000000000",
      realitio: tournament_group.land_data[:realitio_address],
      realitioTimeout: draft_timeout || 3600,
      manager: tournament_group.token_controller_address,
    }
  end

  def create_and_publish!
    raise "Market is already published" if eth_market_id.present? || published?
    raise "Expiration date is in the past" if expires_at < DateTime.now

    args = prepare_draft_for_market_creation_args

    prediction_market_contract_service = Bepro::PredictionMarketContractService.new(network_id: network_id)

    tournament_group = tournament_groups.first

    tx = tournament_group.whitelabel? ?
      prediction_market_contract_service.create_market(args) :
      prediction_market_contract_service.mint_and_create_market(args)

    eth_market_id_from_tx = tx["events"]["MarketCreated"][0]["returnValues"]["marketId"]

    # triggering market update
    Market.create_from_eth_market_id!(network_id, eth_market_id_from_tx)

    # publishing tournaments
    tournaments.each { |tournament| tournament.update(published: true) unless tournament.published }

    reload
  end

  def edit_history
    return [] unless published?

    edits = []

    # only considering changes after market was published
    versions.where('created_at > ?', published_at).each do |version|
      version.changeset.each do |field, values|
        next unless EDITABLE_FIELDS.include?(field.to_sym)
        next if values[0].blank? || values[1].blank?

        edits << {
          field: field,
          old_value: values[0],
          new_value: values[1],
          edited_at: version.created_at,
          edited_by: User.find_by(id: version.whodunnit).try(:username)
        }
      end
    end

    # also checking outcomes
    outcomes.each_with_index do |outcome, i|
      outcome.versions.where('created_at > ?', published_at).map do |version|
        version.changeset.each do |field, values|
          next unless field == 'title'
          next if values[0].blank? || values[1].blank?

          edits << {
            field: "answer #{i + 1}",
            old_value: values[0],
            new_value: values[1],
            edited_at: version.created_at,
            edited_by: User.find_by(id: version.whodunnit).try(:username)
          }
        end
      end
    end

    edits.sort_by { |edit| edit[:edited_at] }.reverse
  end

  def accuracy_report
    return "Market #{slug} is not resolved" unless resolved? && published?

    question_title = title.gsub("\n", ' ')
    outcome_titles = outcomes.map(&:title).map(&:upcase).join(', ')
    most_probable_outcome = outcomes.to_a.max_by(&:closing_price)
    most_probable_outcome_title = most_probable_outcome.title.upcase
    most_probable_outcome_probability = "#{(most_probable_outcome.closing_price * 100.0).round}%"
    winning_outcome_title = voided ? 'Voided' : outcomes.find { |o| o.eth_market_id == resolved_outcome_id }.title.upcase
    correct = most_probable_outcome_title == winning_outcome_title ? 1 : ''
    incorrect = most_probable_outcome_title == winning_outcome_title || voided ? '' : 1

    [
      question_title,
      outcome_titles,
      most_probable_outcome_title,
      most_probable_outcome_probability,
      winning_outcome_title,
      correct,
      incorrect,
      published_at.strftime('%Y/%m/%d'),
      expires_at.strftime('%Y/%m/%d'),
      topics.sort.join(', ')
    ].join(';')
  end

  def og_theme
    tournament_groups.first&.og_theme
  end
end
