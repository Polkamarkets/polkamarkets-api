class TournamentSchedule < ApplicationRecord
  include Schedulable

  belongs_to :tournament_template

  has_and_belongs_to_many :market_schedules
end
