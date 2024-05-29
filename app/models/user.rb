class User < ApplicationRecord
  extend FriendlyId
  include Redeemable
  friendly_id :slug_candidates, use: :slugged

  validates :email, presence: true, uniqueness: true

  def slug_candidates
    [
      :username,
      [:username, SecureRandom.uuid.split('-').first]
    ]
  end

  def send_invitation
    BrevoService.new.send_invitation(email: email)
  end
end
