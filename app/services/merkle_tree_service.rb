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

          # FIXME check if next line is needed
          # merkle_tree = merkle_tree.parse(:json)

          # Convert merkle tree amounts from big number to integer
          merkle_tree[:claims].each do |user_address, merkle_data|
            merkle_data[:amount] = from_big_number_to_integer(merkle_data[:amount], decimals)
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
    # FIXME call service
    # HTTP.post(
    #   "#{Rails.application.config_for(:ethereum)[:"rewards_network_#{network_id}"][:bepro_api_url]}/merkle-tree",
    #   json: {
    #     amounts: converted_amounts
    #   }
    # )
    {"merkleRoot":"0x05e857ad2627320294fdc1904372ccfbdae1f892dbfc6f3292d7647001d2306b","claims":{"0x005DCB2C539EB682F14B7441863C298904D108BD":{"index":0,"amount":2e+21,"proof":["0xca000eeb0e421d2fa0b82d0557493d4b5e0f05310750c2a86f3976d85fccbe70"]},"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61":{"index":1,"amount":5e+21,"proof":["0x8ffa2c85501a8c34ac1e84f1ffbdcdba19f4967fa414cd8b4cd13b1598ff50d5","0xcf793acd9b963171c2d69ac885b9fe144adf456f00936a23153df253d3620325"]},"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A":{"index":2,"amount":5e+21,"proof":["0x10b51283d1db97a125b2c4cf0a2b8a7475e5001ff53cf98871ab174cdc26baea","0xcf793acd9b963171c2d69ac885b9fe144adf456f00936a23153df253d3620325"]}}}
  end
end
