class TournamentGroup < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  validates_presence_of :title, :description

  has_many :tournaments, -> { order(position: :asc) }, inverse_of: :tournament_group, dependent: :nullify
  has_many :markets, through: :tournaments

  acts_as_list

  def network_id_validation
    # checking all tournaments have the same network id
    return if tournaments.map(&:network_id).uniq.count <= 1

    errors.add(:tournaments, 'all tournaments must have the same network id')
  end

  def network_id
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
end
