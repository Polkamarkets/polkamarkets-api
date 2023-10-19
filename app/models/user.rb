class User < ApplicationRecord
  validates :email, presence: true, uniqueness: true

  def username
    self['username'] || self.email.split('@').first
  end
end
