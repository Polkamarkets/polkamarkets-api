module Bepro
  class AchievementsContractService < SmartContractService
    include BigNumberHelper

    def initialize(network_id: nil, api_url: nil, contract_address: nil)
      super(
        network_id: network_id,
        contract_name: 'achievements',
        contract_address:
          contract_address ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :achievements_contract_address) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :achievements_contract_address),
        api_url:
          api_url ||
            Rails.application.config_for(:ethereum).dig(:"network_#{network_id}", :bepro_api_url) ||
            Rails.application.config_for(:ethereum).dig(:"stats_network_#{network_id}", :bepro_api_url),
      )
    end

    def get_achievement_ids
      achievement_index = call(method: 'achievementIndex').to_i

      (0..(achievement_index - 1)).to_a
    end

    def get_achievement(achievement_id)
      achievement_data = call(method: 'achievements', args: achievement_id)

      # fetching achievement details from event
      events = get_events(event_name: 'LogNewAchievement', filter: { achievementId: achievement_id.to_s })

      raise "Achievement #{achievement_id}: LogNewAchievement event not found" if events.blank?
      raise "Achievement #{achievement_id}: LogNewAchievement event count: #{events.count} != 1" if events.count != 1

      event_data = JSON.parse(events[0]['returnValues']['content'])

      {
        id: achievement_id,
        action: Achievement::actions.key(achievement_data[0].to_i),
        occurrences: achievement_data[1].to_i,
        title: event_data['title'],
        description: event_data['description'],
        image_hash: event_data['image'].split('/').last,
        meta: event_data['meta'],
      }
    end

    def get_achievement_token(token_id)
      # ensuring token exists, will raise an error if it does not
      token_uri = call(method: 'tokenURI', args: token_id)
      # tokenId => achievementId mapping in SC
      achievement_id = call(method: 'tokens', args: token_id).to_i

      {
        id: token_id,
        achievement_id: achievement_id,
        uri: token_uri
      }
    end

    def get_user_achievement_tokens(user)
      token_count = call(method: 'balanceOf', args: user)

      token_count.times.map do |token_index|
        token_id = call(method: 'tokenOfOwnerByIndex', args: [user, token_index])
        get_achievement_token(token_id)
      end
    end

    def get_achievement_token_index
      return call(method: 'tokenIndex').to_i
    end

    def get_achievement_token_users
      events = get_events(event_name: 'Transfer')
      # filtering by last occurence of token transfer (current holder)
      events.select!.with_index do |event, i|
        i == events.rindex { |e| e['returnValues']['tokenId'] == event['returnValues']['tokenId'] }
      end

      events.map do |event|
        {
          id: event['returnValues']['tokenId'],
          user: event['returnValues']['to'],
        }
      end
    end
  end
end
