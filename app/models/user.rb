class User < ApplicationRecord
  extend FriendlyId
  friendly_id :username, use: :slugged

  validates :email, presence: true, uniqueness: true
end
