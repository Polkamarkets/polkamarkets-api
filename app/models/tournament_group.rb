class TournamentGroup < ApplicationRecord
  include NetworkHelper
  include Reportable
  include Redeemable
  include Imageable
  include OgImageable
  extend FriendlyId

  friendly_id :title, use: :slugged

  validates_presence_of :title, :description
  validate :network_id_validation
  validate :social_urls_validation

  has_many :tournaments, -> { order(position: :asc) }, inverse_of: :tournament_group, dependent: :nullify
  has_many :markets, through: :tournaments
  has_and_belongs_to_many :users

  acts_as_list

  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }

  SOCIALS = %w[instagram twitter telegram facebook youtube linkedin medium discord].freeze
  IMAGEABLE_FIELDS = [:image_url, :banner_url].freeze
  OG_IMAGEABLE_PATH = 'lands'

  def self.tokens
    # caching value for 1h
    Rails.cache.fetch('lands:tokens', expires_in: 5.minutes) do
      TournamentGroup.all.map(&:token).uniq.compact
    end
  end

  def network_id_validation
    # checking all tournaments have the same network id
    return if tournaments.map(&:network_id).uniq.count <= 1

    errors.add(:tournaments, 'all tournaments must have the same network id')
  end

  def social_urls_validation
    return errors.add(:social_urls, 'social urls must be a hash') unless social_urls.is_a?(Hash)

    return if social_urls.blank?

    social_urls.each do |key, value|
      # errors.add(:social_urls, "#{key} is not a valid social url") unless SOCIALS.include?(key.to_s)
      errors.add(:social_urls, "#{value} is not a valid url") unless value =~ URI::DEFAULT_PARSER.make_regexp
    end
  end

  def network_id
    # TODO: improve this
    return self[:network_id] if self[:network_id].present?

    @_network_id ||= tournaments.first&.network_id
  end

  def tokens
    markets.map(&:token).flatten.uniq.compact
  end

  def topics
    Rails.cache.fetch("tournament_groups:#{id}:topics", expires_in: 1.hour) do
      markets.map(&:topics).flatten.uniq.compact
    end
  end

  def token(refresh: false)
    return tokens.first if token_address.blank?

    Rails.cache.fetch("tournament_groups:#{id}:token", expires_in: 24.hours, force: refresh) do
      token = Bepro::Erc20ContractService.new(network_id: network_id, contract_address: token_address).token_info
      wrapped = token_address.downcase == network_weth_address(network_id).downcase

      token.merge(
        wrapped: wrapped
      )
    end
  end

  def token_controller_address
    self[:token_controller_address] || Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :prediction_market_manager_contract_address)
  end

  def admins(refresh: false)
    return (self[:admins] || []) if token.blank?

    Rails.cache.fetch("tournament_groups:#{id}:admins", expires_in: 24.hours, force: refresh) do
      Bepro::PredictionMarketManagerContractService.new(
        network_id: network_id,
        contract_address: token_controller_address
      ).get_land_admins(token[:address])
    end
  end

  def land_data(refresh: false)
    return {} if token.blank?

    Rails.cache.fetch("tournament_groups:#{id}:land_data", expires_in: 24.hours, force: refresh) do
      Bepro::PredictionMarketManagerContractService.new(
        network_id: network_id,
        contract_address: token_controller_address
      ).get_land_data(token[:address])
    end
  end

  def rank_by
    # returning most common rank_by criteria amongst tournaments
    tournaments.map(&:rank_by).tally.max_by { |_, v| v }&.first || 'claim_winnings_count,earnings_eur'
  end

  def update_counters
    update(users_count: users.count)
  end
end
