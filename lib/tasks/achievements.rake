namespace :achievements do
  desc "checks for new achievements and creates them"
  task :check_new_achievements, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      next if Rails.application.config_for(:ethereum)[:"network_#{network_id}"][:achievements_contract_address].blank?

      achievement_ids = Bepro::AchievementsContractService.new(network_id: network_id).get_achievement_ids
      db_achievement_ids = Achievement.where(network_id: network_id).pluck(:eth_id)

      (achievement_ids - db_achievement_ids).each do |achievement_id|
        begin
          Achievement.create_from_eth_id!(network_id, achievement_id)
        rescue => e
          puts "Error creating achievement #{achievement_id} for network #{network_id}: #{e.message}"
        end
      end
    end
  end

  desc "checks for new achievement tokens and creates them"
  task :check_new_tokens, [:symbol] => :environment do |task, args|
    Rails.application.config_for(:ethereum).network_ids.each do |network_id|
      next if Rails.application.config_for(:ethereum)[:"network_#{network_id}"][:achievements_contract_address].blank?

      token_index = Bepro::AchievementsContractService.new(network_id: network_id).get_achievement_token_index
      token_ids = (1..token_index).to_a
      db_token_ids = AchievementToken.where(network_id: network_id).pluck(:eth_id)

      (token_ids - db_token_ids).each do |achievement_id|
        AchievementToken.create_from_eth_id!(network_id, achievement_id)
      end
    end
  end
end
