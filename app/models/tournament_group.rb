class TournamentGroup < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged

  validates_presence_of :title, :description

  has_many :tournaments

  acts_as_list
end
