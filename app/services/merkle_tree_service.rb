class MerkleTreeService


  def initialize

  end

  def get_amounts_for_merkle_tree(rewards)

      rewards.map do |network_id, user_rewards|
        # get the amount to distribute this timeframe from the env variable and convert amounts in the format of the merkle tree (address, amount)
        amount_to_distribute = Rails.application.config_for(:ethereum)[:"rewards_network_#{network_id}"][:reward_amount_to_distribute].to_f
        timeframe = Rails.application.config_for(:ethereum)[:"rewards_network_#{network_id}"][:reward_timeframe]

        converted_amounts = {}
        user_rewards.map do |user_address, reward|
          converted_amounts[user_address] = amount_to_distribute * reward
        end

        # get previous rewards from db
        previous_rewards = Reward
          .where(
            network_id: network_id,
            timeframe: timeframe,
            token_address: Rails.application.config_for(:ethereum)[:"rewards_network_#{network_id}"][:reward_token_address]
          )
          .order('epoch desc')
          .limit(1)

        unless previous_rewards.blank?
          # if exists, check if claimed or not. If not claimed, add to the reward

          merkle_distributor_contract_service = Bepro::MerkleDistributorContractService.new(network_id: network_id)

          # call contract to check if claimed for each of the users on the previous merkle tree
          previous_merkle_tree = previous_rewards[0][:merkle_tree]

          # puts "previous_rewards[0]: #{previous_merkle_tree['claims']}"

          previous_merkle_tree['claims'].each do |user_address, merkle_data|
            # if not claimed add to converted_amounts
            unless merkle_distributor_contract_service.is_claimed(merkle_data['index'])
              converted_amounts[user_address].blank? ?
                converted_amounts[user_address] = merkle_data['amount']
                : converted_amounts[user_address] += merkle_data['amount']
            end
          end
        end

        [
        network_id,
        converted_amounts.map do |user_address, amount|
          {account: user_address, amount: amount}
        end
        ]
      end.to_h
  end

  def get_merkle_tree(rewards)
    # Use BigNumberHelper to convert amounts

    # call new api to get merkle tree with proof

    # after the response convert back to normal amounts

    # save on the database

  end

end
