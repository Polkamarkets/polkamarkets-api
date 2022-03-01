class AchievementToken < ApplicationRecord
  validates_presence_of :achievement

  validates_uniqueness_of :eth_id, scope: :network_id

  belongs_to :achievement, inverse_of: :tokens

  def self.create_from_eth_id!(network_id, eth_id)
    raise "AchievementToken #{eth_id} is already created" if AchievementToken.where(network_id: network_id, eth_id: eth_id).exists?

    eth_data =
      Rails.cache.fetch("achievement_tokens:network_#{network_id}:#{eth_id}", force: true) do
        Bepro::AchievementsContractService.new(network_id: network_id).get_achievement_token(eth_id)
      end

    achievement = Achievement.find_by!(network_id: network_id, eth_id: eth_data[:achievement_id])

    achievement_token = AchievementToken.new(
      network_id: network_id,
      eth_id: eth_id,
    )

    achievement_token.achievement = achievement
    achievement_token.save!
    achievement_token
  end

  def image_url
    self['image_url'] || achievement.image_url
  end
end
