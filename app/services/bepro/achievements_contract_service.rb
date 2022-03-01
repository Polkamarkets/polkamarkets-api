module Bepro
  class AchievementsContractService < SmartContractService
    include BigNumberHelper

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        contract_name: 'achievements',
        contract_address: contract_address || Rails.application.config_for(:ethereum)["network_#{network_id}"]['achievements_contract_address'],
        api_url: api_url || Rails.application.config_for(:ethereum)["network_#{network_id}"]['bepro_api_url']
      )
    end

    def get_achievement_ids
      achievement_index = call(method: 'achievementIndex')[0].to_i

      (0..(achievement_index - 1)).to_a
    end

    def get_achievement(achievement_id)
      achievement_data = call(method: 'achievements', args: achievement_id)

      {
        id: achievement_id,
        action: Achievement::actions.key(achievement_data[0].to_i),
        occurrences: achievement_data[1].to_i,
      }
    end

    def get_achievement_token(token_id)
      # ensuring token exists, will raise an error if it does not
      call(method: 'tokenURI', args: token_id)
      # tokenId => achievementId mapping in SC
      achievement_id = call(method: 'tokens', args: token_id)[0].to_i

      {
        id: token_id,
        achievement_id: achievement_id,
      }
    end
  end
end
