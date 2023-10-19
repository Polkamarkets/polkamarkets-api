class User < ApplicationRecord
  def username
    self['username'] || self.email.split('@').first
  end
end
