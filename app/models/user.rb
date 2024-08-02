class User < ApplicationRecord
  extend FriendlyId
  include Redeemable
  friendly_id :slug_candidates, use: :slugged

  has_paper_trail skip: [:inactive_since]

  has_many :likes, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :reports, dependent: :destroy
  has_many :user_idps, dependent: :destroy
  has_and_belongs_to_many :tournament_groups

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
