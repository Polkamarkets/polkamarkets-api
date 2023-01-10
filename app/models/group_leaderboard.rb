class GroupLeaderboard < ApplicationRecord
 include ApplicationHelper

  extend FriendlyId
  friendly_id :title, use: :slugged

  validates_presence_of :title, :created_by, :users

  validate :created_by_address_validation
  validate :users_addresses_validation

  after_create do
    GroupLeaderboardBannerWorker.perform_async(id)
  end

  def as_json(options = nil)
    super(methods: :image_url, except: [:image_hash])
  end

  def created_by_address_validation
    errors.add(:created_by, 'eth address is not valid') unless eth_address_valid?(created_by)
  end

  def users_addresses_validation
    users.each do |user|
      errors.add(:users, 'eth address is not valid') unless eth_address_valid?(user)
    end
  end

  def image_url
    image_hash.present? ? IpfsService.image_url_from_hash(image_hash) : nil
  end

  def update_banner_image
    banner_image_url = BannerbearService.new.create_group_leaderboard_banner_image(self)
    self.update(banner_url: banner_image_url)
  end

  def network_id
    # TODO add network id to group leaderboards
    Rails.application.config_for(:ethereum).network_ids.first
  end

  def leaderboard_users
    leaderboard = StatsService.new.get_leaderboard(timeframe: 'at')[network_id.to_i] || []

    balances = users.map do |user|
      {
        address: user,
        balance: leaderboard.find { |l| l[:user].downcase == user.downcase }&.dig(:erc20_balance) || 0
      }
    end

    # sorting by balance
    balances.sort_by { |user| -user[:balance] }
  end
end
