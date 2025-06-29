class TournamentTemplate < ApplicationRecord
  include Templatable

  validate :template_validation
  validates :template_type, presence: true

  enum template_type: {
    general: 0,
  }

  def template_validation
    # TODO
  end

  def template_variables(schedule_id)
    {}
  end
end
