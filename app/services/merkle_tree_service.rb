class MerkleTreeService
  include BigNumberHelper

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

        contract_addresses = Rails.application.config_for(:ethereum).dig(:"rewards_network_#{network_id}", :reward_merkle_contract_addresses)

        # iterate over each contract address and get the token address
        contract_addresses.each do |contract_address|
          merkle_distributor_contract_service = Bepro::MerkleDistributorContractService.new(network_id: network_id, contract_address: contract_address)
          token_address = merkle_distributor_contract_service.erc20_address


          # get previous rewards from db
          previous_rewards = Reward
            .where(
              network_id: network_id,
              timeframe: timeframe,
              token_address: token_address
            )
            .order('epoch desc')
            .first()

          current_epoch = 1

          unless previous_rewards.blank?
            current_epoch = previous_rewards[:epoch] + 1

            # if exists, check if claimed or not. If not claimed, add to the reward

            # call contract to check if claimed for each of the users on the previous merkle tree
            previous_merkle_tree = previous_rewards[:merkle_tree]

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

          decimals = merkle_distributor_contract_service.erc20_decimals

          # Convert amounts to big number
          converted_amounts = converted_amounts.map do |user_address, amount|
            {account: user_address, amount: from_integer_to_big_number(amount, decimals)}
          end

          # call new api to get merkle tree with proof
          merkle_tree = call_merkle_tree_api(network_id, converted_amounts)


          # Convert merkle tree amounts from big number to integer
          merkle_tree['claims'].each do |user_address, merkle_data|
            merkle_data['amount'] = from_big_number_to_integer(merkle_data['amount'], decimals)
          end

          # save on the database
          Reward.create(
            epoch: current_epoch,
            timeframe: timeframe,
            token_address: token_address,
            network_id: network_id,
            merkle_tree: merkle_tree
          )
        end
      end
  end

  private

  def call_merkle_tree_api(network_id, converted_amounts)
    response = HTTP.post(
      "#{Rails.application.config_for(:ethereum)[:merkle_generator_api_url]}",
      json: converted_amounts
    )

    JSON.parse(response)
  end
end
