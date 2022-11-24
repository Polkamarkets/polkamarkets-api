class GroupLeaderboard < ApplicationRecord
 include ApplicationHelper

  extend FriendlyId
  friendly_id :title, use: :slugged

  validates_presence_of :title, :created_by, :users

  validate :created_by_address_validation
  validate :users_addresses_validation

  def created_by_address_validation
    errors.add(:created_by, 'eth address is not valid') unless eth_address_valid?(created_by)
  end

  def users_addresses_validation
    users.each do |user|
      errors.add(:users, 'eth address is not valid') unless eth_address_valid?(user)
    end
  end
end
