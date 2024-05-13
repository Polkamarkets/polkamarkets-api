class TournamentGroup < ApplicationRecord
  include NetworkHelper
  extend FriendlyId
  friendly_id :title, use: :slugged

  validates_presence_of :title, :description
  validate :network_id_validation
  validate :social_urls_validation

  has_many :tournaments, -> { order(position: :asc) }, inverse_of: :tournament_group, dependent: :nullify
  has_many :markets, through: :tournaments

  acts_as_list

  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }

  SOCIALS = %w[instagram twitter telegram facebook youtube linkedin medium discord].freeze

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

  def users(refresh: false)
    # TODO: store counter in postgres
    Rails.cache.fetch("tournament_groups:#{id}:users", expires_in: 24.hours, force: refresh) do
      eth_market_ids = markets.map(&:eth_market_id).uniq

      Activity.where(market_id: eth_market_ids, network_id: network_id).distinct.count(:address)
    end
  end

  def tokens
    markets.map(&:token).flatten.uniq
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

  def admins(refresh: false)
    return [] if token.blank?

    Rails.cache.fetch("tournament_groups:#{id}:admins", expires_in: 24.hours, force: refresh) do
      Bepro::PredictionMarketManagerContractService.new(network_id: network_id).get_land_admins(token[:address])
    end
  end
end
