class User < ApplicationRecord
  extend FriendlyId
  friendly_id :username, use: :slugged

  validates :email, presence: true, uniqueness: true

  devise :omniauthable,
         omniauth_providers: [:google_oauth2] # add omniauthable field and add the providers under omniauth_providers

  def self.from_omniauth(access_token)
    data = access_token.info
    user = User.where(email: data['email']).first

    unless user
        user = User.create(email: data['email'], username: data['name'], avatar: data['image'],)
    else
        user.update(username: data['name'], avatar: data['image'])
    end
    user
end
end
