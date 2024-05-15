class Report < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :reportable, polymorphic: true

  validates_presence_of :content

  ALLOWED_REPORTABLE_TYPES = %w[Market TournamentGroup Tournament Comment].freeze

  validates :reportable_type, inclusion: { in: ALLOWED_REPORTABLE_TYPES }
end
