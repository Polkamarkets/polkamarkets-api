class Achievement < ApplicationRecord
  validates_presence_of :eth_id, :network_id, :action, :occurrences
  validates_uniqueness_of :eth_id, scope: :network_id

  DEFAULT_IMAGE_URL = 'https://ipfs.io/ipfs/QmTxWoieQryavmHnYkgpiZTFLAwrovzmFjJfGUHvZX2JnP'

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

    achievement_ids = Rpc::AchievementsContractService.new(network_id: network_id).get_achievement_ids
    # invalid achievement
    raise "Achievement #{eth_id} does not exist" unless achievement_ids.include?(eth_id)

    eth_data =
      Rails.cache.fetch("achievements:network_#{network_id}:#{eth_id}", force: true) do
        Rpc::AchievementsContractService.new(network_id: network_id).get_achievement(eth_id)
      end

    achievement = Achievement.new(
      action: eth_data[:action],
      occurrences: eth_data[:occurrences],
      eth_id: eth_id,
      network_id: network_id,
      title: eth_data[:title],
      description: eth_data[:description],
      image_url: IpfsService.image_url_from_hash(eth_data[:image_hash])
    )

    achievement.save!
    achievement
  end

  def image_url
    return DEFAULT_IMAGE_URL if self['image_url'].blank?

    # TODO: save image_hash only and concatenate with ipfs hosting provider
    image_hash = self['image_url'].split('/').last

    IpfsService.image_url_from_hash(image_hash)
  end

  def eth_data(refresh: false)
    return @eth_data if @eth_data.present? && !refresh

    @eth_data ||=
      Rails.cache.fetch("achievements:network_#{network_id}:#{eth_id}", force: refresh) do
        Rpc::AchievementsContractService.new(network_id: network_id).get_achievement(eth_id)
      end
  end

  def token_count
    tokens.count
  end

  def meta
    eth_data[:meta]
  end
end
