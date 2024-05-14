class User < ApplicationRecord
  extend FriendlyId
  friendly_id :slug_candidates, use: :slugged

  validates :email, presence: true, uniqueness: true

  before_validation :generate_redeem_code, if: -> { redeem_code.blank? }

  def generate_redeem_code
    # random string with 6 downcase and uppercase letters
    redeem_code = SecureRandom.alphanumeric(6)

    # ensure uniqueness
    while User.exists?(redeem_code: redeem_code)
      redeem_code = SecureRandom.alphanumeric(6)
    end

    self.redeem_code = redeem_code
  end

  def slug_candidates
    [
      :username,
      [:username, SecureRandom.uuid.split('-').first]
    ]
  end
end
