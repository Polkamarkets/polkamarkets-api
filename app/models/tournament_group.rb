class TournamentGroup < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  validates_presence_of :title, :description

  has_many :tournaments, -> { order(position: :asc) }, inverse_of: :tournament_group, dependent: :nullify

  acts_as_list
end
