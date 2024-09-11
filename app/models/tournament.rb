class Tournament < ApplicationRecord
  extend FriendlyId
  include Reportable

  friendly_id :title, use: :slugged

  validates_presence_of :title, :description, :network_id
  validate :markets_network_id_validation
  validate :rank_by_validation
  validate :rewards_validation

  has_and_belongs_to_many :markets
  belongs_to :tournament_group, optional: true

  acts_as_list scope: :tournament_group

  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }

  RANK_CRITERIA = [
    :markets_created,
    :volume_eur,
    :tvl_volume_eur,
    :liquidity_eur,
    :tvl_liquidity_eur,
    :earnings_eur,
    :bond_volume,
    :claim_winnings_count,
    :transactions,
    :upvotes,
    :downvotes
  ].freeze

  def markets_network_id_validation
    markets.each do |market|
      errors.add(:markets, 'network id is not valid') unless market.network_id == network_id
    end
  end

  def rank_by
    self[:rank_by] || 'claim_winnings_count,earnings_eur'
  end

  def rank_by_validation
    return if rank_by.blank?

    # allowing multiple criteria, comma separated
    rank_by.split(',').each do |rank_criteria|
      errors.add(:rank_by, "#{rank_criteria} is not a valid rank criteria") unless RANK_CRITERIA.include?(rank_criteria.to_sym)
    end
  end

  def rewards_validation
    return if rewards.blank?

    rewards.each do |reward|
      errors.add(:rewards, 'reward is not valid') unless reward['from'].present? &&
        reward['to'].present? &&
        (reward['reward'].present? || reward['title'].present?) && # TODO: remove reward['reward'] legacy
        reward['from'] <= reward['to']
    end
  end

  def expires_at
    self[:expires_at] || markets.map(&:expires_at).max
  end

  def closed?
    expires_at < Time.now - 1.day
  end

  def users(refresh: false)
    # TODO: store counter in postgres
    Rails.cache.fetch("tournaments:#{id}:users", expires_in: 24.hours, force: refresh) do
      eth_market_ids = markets.map(&:eth_market_id).uniq

      Activity.where(market_id: eth_market_ids, network_id: network_id).distinct.count(:address)
    end
  end

  def tokens
    markets.map(&:token).flatten.uniq.compact
  end

  def token(refresh: false)
    return tokens.first if tournament_group&.token_address.blank?

    tournament_group&.token(refresh: refresh)
  end

  def admins
    return [] if tournament_group.blank?

    tournament_group.admins
  end
end
