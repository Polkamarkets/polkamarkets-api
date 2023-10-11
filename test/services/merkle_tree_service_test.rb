require "test_helper"

class MerkleTreeServiceTest < ActiveSupport::TestCase

  def mocked_env
    {
      "REWARDS_NETWORK_IDS" => "1",
      "REWARDS_NETWORK_1_REWARD_CONTRACT_CHAIN" => 'blockscout',
      "REWARDS_NETWORK_1_REWARD_AMOUNT_TO_DISTRIBUTE" => '10000',
      "REWARDS_NETWORK_1_REWARD_TIMEFRAME" => '1w',
      "REWARDS_NETWORK_1_BEPRO_API_URL" => 'http://localhost:3333',
      "REWARDS_NETWORK_1_MERKLE_CONTRACT_ADDRESSES" => '0x62552dcB7cd91E08d00f93C66a34F3521bBA172a',
      "ETHEREUM_MERKLE_GENERATOR_API_URL" => 'http://localhost:3344',
    }
  end

  # from here: https://gist.github.com/jazzytomato/79bb6ff516d93486df4e14169f4426af
  def mock_enviroment(env: "test", partial_env_hash: {})
    old_env_mode = Rails.env
    old_env = ENV.to_hash

    Rails.env = env
    ENV.update(partial_env_hash)

    begin
      yield
    ensure
      Rails.env = old_env_mode
      ENV.replace(old_env)
    end
  end

  test "run merkle tree" do
    mock_enviroment(env:"production", partial_env_hash:mocked_env) do

      # Create reward on database
      Reward.create(
        epoch: 1,
        timeframe: '1w',
        token_address: '0xB7837bfca452ce8819F9C21007FfB207795e800a',
        network_id: 1,
        merkle_tree: {
          "merkleRoot"=> "0x5ef029727e1e4c7a0e6bf02298c73a9dd1529b7e8a7a32216eec28bdfd53bc2b",
          "claims" => {
            "0x005DCB2C539EB682F14B7441863C298904D108BD"=> {
              "index" => 0,
              "amount"=> 2000,
              "proof"=> [
                "0x13c1a90a1475d38de9a2bc823b16f9a4e03c9ced3b95efc140936e16d1882d75",
                "0x90cc5cd1293cce25e0ce286e5b9e74023023b4da6cefcf9ba4ddfeda8ce662d8"
              ]
            }
          }
        }
      )

      merkleTreeService = MerkleTreeService.new
      amounts = merkleTreeService.get_amounts_for_merkle_tree(
        {
          "1"=>{"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A"=>0.5, "0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61"=>0.5},
        })

      # Get last reward created
      reward_created = Reward.find_by(
        network_id: 1,
        timeframe: '1w',
        token_address:'0xB7837bfca452ce8819F9C21007FfB207795e800a',
        epoch: 2
      )

      assert_not_nil reward_created
      assert_equal reward_created[:merkle_tree], {"claims"=>{"0x005DCB2C539EB682F14B7441863C298904D108BD"=>{"index"=>0, "proof"=>["0xca000eeb0e421d2fa0b82d0557493d4b5e0f05310750c2a86f3976d85fccbe70"], "amount"=>2000.0}, "0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61"=>{"index"=>1, "proof"=>["0x8ffa2c85501a8c34ac1e84f1ffbdcdba19f4967fa414cd8b4cd13b1598ff50d5", "0xcf793acd9b963171c2d69ac885b9fe144adf456f00936a23153df253d3620325"], "amount"=>5000.0}, "0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A"=>{"index"=>2, "proof"=>["0x10b51283d1db97a125b2c4cf0a2b8a7475e5001ff53cf98871ab174cdc26baea", "0xcf793acd9b963171c2d69ac885b9fe144adf456f00936a23153df253d3620325"], "amount"=>5000.0}}, "merkleRoot"=>"0x05e857ad2627320294fdc1904372ccfbdae1f892dbfc6f3292d7647001d2306b"}


    end
  end
end