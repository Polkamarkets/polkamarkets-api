namespace :achievements do
  desc "checks for new markets and creates them"
  task :check_new_achievements, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      next if Rails.application.config_for(:ethereum)["network_#{network_id}"]['achievements_contract_address'].blank?

      achievement_ids = Bepro::AchievementsContractService.new(network_id: network_id).get_achievement_ids
      db_achievement_ids = Achievement.where(network_id: network_id).pluck(:eth_id)

      (achievement_ids - db_achievement_ids).each do |achievement_id|
        Achievement.create_from_eth_id!(network_id, achievement_id)
      end
    end
  end
end
