class Achievement < ApplicationRecord
  validates_presence_of :eth_id, :network_id, :action, :occurrences
  validates_uniqueness_of :eth_id, scope: :network_id

  DEFAULT_IMAGE_URL = 'https://ipfs.infura.io:5001/api/v0/cat?arg=QmTxWoieQryavmHnYkgpiZTFLAwrovzmFjJfGUHvZX2JnP'

  has_many :tokens, class_name: "AchievementToken", dependent: :destroy, inverse_of: :achievement

  enum action: {
    buy: 0,
    add_liquidity: 1,
    bond: 2,
    claim_winnings: 3,
    create_market: 4,
  }

  scope :verified, -> { where(verified: true) }

  def self.create_from_eth_id!(network_id, eth_id)
    raise "Achievement #{eth_id} is already created" if Achievement.where(network_id: network_id, eth_id: eth_id).exists?

    achievement_ids = Bepro::AchievementsContractService.new(network_id: network_id).get_achievement_ids
    # invalid achievement
    raise "Achievement #{eth_id} does not exist" unless achievement_ids.include?(eth_id)

    eth_data =
      Rails.cache.fetch("achievements:network_#{network_id}:#{eth_id}", force: true) do
        Bepro::AchievementsContractService.new(network_id: network_id).get_achievement(eth_id)
      end

    achievement = Achievement.new(
      action: eth_data[:action],
      occurrences: eth_data[:occurrences],
      eth_id: eth_id,
      network_id: network_id
    )

    achievement.save!
    achievement
  end

  def image_url
    self['image_url'] || DEFAULT_IMAGE_URL
  end

  def eth_data(refresh: false)
    return @eth_data if @eth_data.present? && !refresh

    @eth_data ||=
      Rails.cache.fetch("achievements:network_#{network_id}:#{eth_id}", force: refresh) do
        Bepro::AchievementsContractService.new(network_id: network_id).get_achievement(eth_id)
      end
  end
end
