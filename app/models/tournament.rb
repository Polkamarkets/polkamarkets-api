class Tournament < ApplicationRecord
  include Reportable
  include Imageable
  include OgImageable
  extend FriendlyId

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
    :earnings_eur,
    :claim_winnings_count,
  ].freeze

  IMAGEABLE_FIELDS = [:image_url].freeze

  OG_IMAGEABLE_PATH = 'contests'
  OG_IMAGEABLE_FIELDS = %i[title image_url].freeze

  def self.create_draft_from_template!(template_id, schedule_id)
    tournament_template = TournamentTemplate.find(template_id)
    tournament_schedule = TournamentSchedule.find(schedule_id)

    expires_at = tournament_schedule.next_run_expires_at

    template_variables = tournament_template.template_variables(schedule_id).merge(tournament_schedule.next_run_variables)
    tournament_variables = tournament_schedule.tournament_variables

    template_variables.deep_stringify_keys!
    tournament_variables.deep_stringify_keys!

    # checking template variables against tournament variables
    if tournament_template.variables & template_variables.keys != tournament_template.variables
      raise "Template variables do not match tournament variables"
    end

    if ['network_id', 'tournament_group_id'].any? { |key| tournament_variables[key].blank? }
      raise "Tournament variables 'network_id' and 'tournament_group_id' cannot be blank"
    end

    raise "Tournament variables 'expires_at' must be a valid date" unless expires_at.present?

    tournament = Tournament.new
    tournament.expires_at = expires_at
    tournament_variables.each do |key, value|
      tournament[key] = value
    end

    tournament_template.template.each do |key, value|
      puts "key: #{key}, value: #{value}"
      tournament[key] = tournament_template.template_field(key, template_variables)
    end

    tournament.save!
    tournament
  end

  def markets_network_id_validation
    markets.each do |market|
      errors.add(:markets, 'network id is not valid') unless market.network_id == network_id
    end
  end

  def rank_by
    self[:rank_by] || 'claim_winnings_count'
  end

  def rank_by_validation
    return if rank_by.blank?

    # allowing multiple criteria, comma separated
    rank_by.split(',').each do |rank_criteria|
      errors.add(:rank_by, "#{rank_criteria} is not a valid rank criteria") unless RANK_CRITERIA.include?(rank_criteria.to_sym)
    end

    if rank_by_priority.present?
      if rank_by_priority.to_sym == :highest_ranking
        # disabling this at the moment
        # checking both rankings have the same number of rewards
        # errors.add(:rank_by_priority, 'rank_by_priority highest_ranking should have the same number of rewards for both rankings') unless ranking_rewards_places('earnings_eur') == ranking_rewards_places('claim_winnings_count')
      else
        errors.add(:rank_by_priority, "#{rank_by_priority} is not a valid rank criteria") unless RANK_CRITERIA.include?(rank_by_priority.to_sym)
      end
    end
  end

  def rewards_validation
    return if rewards.blank?

    rewards.each do |reward|
      errors.add(:rewards, 'reward is not valid') unless reward['from'].present? &&
        reward['to'].present? &&
        (reward['reward'].present? || reward['title'].present?) && # TODO: remove reward['reward'] legacy
        reward['from'] <= reward['to'] &&
        ((reward['rank_by'].present? && RANK_CRITERIA.include?(reward['rank_by'].to_sym)) || single_ranking?)
    end
  end

  def rewards
    return [] if self[:rewards].blank?

    self[:rewards].map do |reward|
      # adding rank_by criteria if not present
      reward['rank_by'] ||= rank_by.split(',').first

      reward
    end
  end

  def single_ranking?
    rank_by.split(',').size <= 1
  end

  def rank_by_priority
    return nil if single_ranking?

    self[:rank_by_priority]
  end

  def ranking_rewards_places(rank_by)
    rewards
      .select { |reward| reward['rank_by'] == rank_by }
      .map { |reward| reward['to'] }
      .max || 0
  end

  def rank_by_priority_places
    return 0 if rank_by_priority.blank?

    ranking_rewards_places(rank_by_priority.to_s)
  end

  def expires_at
    [self[:expires_at], markets.map(&:expires_at).max].compact.max
  end

  def closed?
    expires_at < Time.now - 1.day
  end

  def users(refresh: false)
    Rails.cache.fetch("tournaments:#{id}:users", expires_in: 24.hours, force: refresh) do
      LeaderboardService.new.get_tournament_leaderboard(network_id, id, from: 0, to: 0)[:count]
    end
  end

  def tokens
    markets.map(&:token).flatten.uniq.compact
  end

  def token(refresh: false)
    Rails.cache.fetch("tournaments:#{id}:token", expires_in: 24.hours, force: refresh) do
      next tokens.first if tournament_group&.token_address.blank?

      tournament_group&.token(refresh: refresh)
    end
  end

  def admins
    return [] if tournament_group.blank?

    tournament_group.admins
  end

  def og_theme
    tournament_group&.og_theme
  end
end
