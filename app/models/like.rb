class Like < ApplicationRecord
  belongs_to :user
  belongs_to :likeable, polymorphic: true

  validates :user_id, uniqueness: { scope: %i[likeable_type likeable_id] }

  ALLOWED_LIKEABLE_TYPES = %w[Market Comment].freeze

  validates :likeable_type, inclusion: { in: ALLOWED_LIKEABLE_TYPES }
end
