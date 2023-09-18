require "test_helper"

class RewardServiceTest < ActiveSupport::TestCase

  def mocked_env
    {
      "REWARDS_NETWORK_IDS" => "1",
      "REWARDS_NETWORK_1_REWARD_CONTRACT_CHAIN" => 'blockscout'
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

  test "compute rewards simple case 50%" do
    mock_enviroment(env:"production", partial_env_hash:mocked_env) do

      spy1 = Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
        assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

        if timestamp == 1688688000
          { blockNumber: 3 }
        elsif timestamp == 1689292800
          { blockNumber: 8 }
        end
      end

      spy2 = Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
        [
          {:address=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1680794871, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>3},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>2, :action=>"add_liquidity", :shares=>2000, :timestamp=>1673337153, :block_number=>3},
        ]
      end

      spy3 = Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
        [
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>1, :action=>"lock", :lock_amount=>100, :timestamp=>1674194680, :block_number=>1},
          {:user=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :item_id=>1, :action=>"lock", :lock_amount=>200, :timestamp=>1695431077, :block_number=>2},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>3, :action=>"lock", :lock_amount=>100, :timestamp=>1697229205, :block_number=>3},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>2, :action=>"lock", :lock_amount=>50, :timestamp=>1697229205, :block_number=>1},
        ]
      end

      spyTiersInfo = Spy.on_instance_method(RewardsService, :get_tiers).and_return do |networkId|
        [{
          max_amount: 0,
          multiplier: 1
        },
        {
          max_amount: 1000,
          multiplier: 1.3
        },
        {
          max_amount: 5000,
          multiplier: 1.5
        },
        {
          max_amount: 10000,
          multiplier: 1.7
        },
        {
          max_amount: 20000,
          multiplier: 2.1
        }
      ]
      end
      rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)
      assert_equal rewards, {"1"=>{"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A"=>0.5, "0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61"=>0.5}}

      spy1.unhook
      spy2.unhook
      spy3.unhook
      spyTiersInfo.unhook
    end
  end

  test "compute rewards simple case with multiplier" do
    mock_enviroment(env:"production", partial_env_hash:mocked_env) do
      spy1 = Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
        assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

        if timestamp == 1688688000
          { blockNumber: 3 }
        elsif timestamp == 1689292800
          { blockNumber: 8 }
        end
      end

      spy2 = Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
        [
          {:address=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1680794871, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>2},
        ]
      end

      spy3 = Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
        [
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>1, :action=>"lock", :lock_amount=>100, :timestamp=>1674194680, :block_number=>1},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>3, :action=>"lock", :lock_amount=>100, :timestamp=>1697229205, :block_number=>2},
        ]
      end

      spyTiersInfo = Spy.on_instance_method(RewardsService, :get_tiers).and_return do |networkId|
        [{
          max_amount: 0,
          multiplier: 1
        },
        {
          max_amount: 1000,
          multiplier: 1.3
        },
        {
          max_amount: 5000,
          multiplier: 1.5
        },
        {
          max_amount: 10000,
          multiplier: 1.7
        },
        {
          max_amount: 20000,
          multiplier: 2.1
        }
      ]
      end

      rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)
      assert_equal rewards, {"1"=>{"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61"=>0.4347826086956521, "0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A"=>0.5652173913043478}}

      spy1.unhook
      spy2.unhook
      spy3.unhook
      spyTiersInfo.unhook
    end
  end

  test "compute rewards top changing" do
    mock_enviroment(env:"production", partial_env_hash:mocked_env) do
      spy1 = Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
        assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

        if timestamp == 1688688000
          { blockNumber: 3 }
        elsif timestamp == 1689292800
          { blockNumber: 8 }
        end
      end

      spy2 = Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
        [
          {:address=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1680794871, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>2, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>4},
        ]
      end

      spy3 = Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
        [
          {:user=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :item_id=>1, :action=>"lock", :lock_amount=>100, :timestamp=>1674194680, :block_number=>1},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>3, :action=>"lock", :lock_amount=>200, :timestamp=>1697229205, :block_number=>3},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>2, :action=>"lock", :lock_amount=>300, :timestamp=>1697229205, :block_number=>5},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>2, :action=>"unlock", :lock_amount=>300, :timestamp=>1697229205, :block_number=>9},
        ]
      end

      spyTiersInfo = Spy.on_instance_method(RewardsService, :get_tiers).and_return do |networkId|
        [{
          max_amount: 0,
          multiplier: 1
        },
        {
          max_amount: 1000,
          multiplier: 1.3
        },
        {
          max_amount: 5000,
          multiplier: 1.5
        },
        {
          max_amount: 10000,
          multiplier: 1.7
        },
        {
          max_amount: 20000,
          multiplier: 2.1
        }
      ]
      end

      rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)

      assert_equal rewards, {"1"=>{"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A"=>0.8333333333333333, "0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61"=>0.16666666666666666}}

      spy1.unhook
      spy2.unhook
      spy3.unhook
      spyTiersInfo.unhook
    end
  end

  test "compute rewards top changing in the end" do
    mock_enviroment(env:"production", partial_env_hash:mocked_env) do
      spy1 = Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
        assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

        if timestamp == 1688688000
          { blockNumber: 3 }
        elsif timestamp == 1689292800
          { blockNumber: 8 }
        end
      end

      spy2 = Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
        [
          {:address=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1680794871, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>2, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>4},
        ]
      end

      spy3 = Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
        [
          {:user=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :item_id=>1, :action=>"lock", :lock_amount=>100, :timestamp=>1674194680, :block_number=>1},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>3, :action=>"lock", :lock_amount=>200, :timestamp=>1697229205, :block_number=>3},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>2, :action=>"lock", :lock_amount=>300, :timestamp=>1697229205, :block_number=>5},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>2, :action=>"unlock", :lock_amount=>300, :timestamp=>1697229205, :block_number=>8},
        ]
      end

      spyTiersInfo = Spy.on_instance_method(RewardsService, :get_tiers).and_return do |networkId|
        [{
          max_amount: 0,
          multiplier: 1
        },
        {
          max_amount: 1000,
          multiplier: 1.3
        },
        {
          max_amount: 5000,
          multiplier: 1.5
        },
        {
          max_amount: 10000,
          multiplier: 1.7
        },
        {
          max_amount: 20000,
          multiplier: 2.1
        }
      ]
      end

      rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)

      assert_equal rewards, {"1"=>{"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A"=>0.75, "0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61"=>0.25}}

      spy1.unhook
      spy2.unhook
      spy3.unhook
      spyTiersInfo.unhook
    end
  end

  test "compute rewards user locked but without liquidity" do
    mock_enviroment(env:"production", partial_env_hash:mocked_env) do
      spy1 = Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
        assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

        if timestamp == 1688688000
          { blockNumber: 3 }
        elsif timestamp == 1689292800
          { blockNumber: 8 }
        end
      end

      spy2 = Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
        [
          {:address=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1680794871, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>2, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>4},
        ]
      end

      spy3 = Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
        [
          {:user=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :item_id=>1, :action=>"lock", :lock_amount=>100, :timestamp=>1674194680, :block_number=>1},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>3, :action=>"lock", :lock_amount=>200, :timestamp=>1697229205, :block_number=>3},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>2, :action=>"lock", :lock_amount=>300, :timestamp=>1697229205, :block_number=>5},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>2, :action=>"unlock", :lock_amount=>300, :timestamp=>1697229205, :block_number=>8},
          {:user=>"0x1ABC7154748D1CE5144478CDEB574AE244B939B5", :item_id=>3, :action=>"lock", :lock_amount=>600, :timestamp=>1697229205, :block_number=>1},
        ]
      end

      spyTiersInfo = Spy.on_instance_method(RewardsService, :get_tiers).and_return do |networkId|
        [{
          max_amount: 0,
          multiplier: 1
        },
        {
          max_amount: 1000,
          multiplier: 1.3
        },
        {
          max_amount: 5000,
          multiplier: 1.5
        },
        {
          max_amount: 10000,
          multiplier: 1.7
        },
        {
          max_amount: 20000,
          multiplier: 2.1
        }
      ]
      end

      rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)

      assert_equal rewards, {"1"=>{"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A"=>0.75, "0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61"=>0.25}}

      spy1.unhook
      spy2.unhook
      spy3.unhook
      spyTiersInfo.unhook
    end
  end

  test "compute rewards remove liquidity" do
    mock_enviroment(env:"production", partial_env_hash:mocked_env) do
      spy1 = Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
        assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

        if timestamp == 1688688000
          { blockNumber: 3 }
        elsif timestamp == 1689292800
          { blockNumber: 8 }
        end
      end

      spy2 = Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
        [
          {:address=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1680794871, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>2, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>4},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"remove_liquidity", :shares=>100, :timestamp=>1673337153, :block_number=>6},
        ]
      end

      spy3 = Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
        [
          {:user=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :item_id=>1, :action=>"lock", :lock_amount=>100, :timestamp=>1674194680, :block_number=>1},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>3, :action=>"lock", :lock_amount=>200, :timestamp=>1697229205, :block_number=>3},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>2, :action=>"lock", :lock_amount=>300, :timestamp=>1697229205, :block_number=>5},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>2, :action=>"unlock", :lock_amount=>300, :timestamp=>1697229205, :block_number=>8},
          {:user=>"0x1ABC7154748D1CE5144478CDEB574AE244B939B5", :item_id=>3, :action=>"lock", :lock_amount=>600, :timestamp=>1697229205, :block_number=>1},
        ]
      end

      spyTiersInfo = Spy.on_instance_method(RewardsService, :get_tiers).and_return do |networkId|
        [{
          max_amount: 0,
          multiplier: 1
        },
        {
          max_amount: 1000,
          multiplier: 1.3
        },
        {
          max_amount: 5000,
          multiplier: 1.5
        },
        {
          max_amount: 10000,
          multiplier: 1.7
        },
        {
          max_amount: 20000,
          multiplier: 2.1
        }
      ]
      end

      rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)

      assert_equal rewards, {"1"=>{"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A"=>0.7222222222222222, "0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61"=>0.2777777777777778}}

      spy1.unhook
      spy2.unhook
      spy3.unhook
      spyTiersInfo.unhook
    end
  end

  test "compute rewards liquidity changing in the end and start" do
    mock_enviroment(env:"production", partial_env_hash:mocked_env) do
      spy1 = Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
        assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

        if timestamp == 1688688000
          { blockNumber: 3 }
        elsif timestamp == 1689292800
          { blockNumber: 8 }
        end
      end

      spy2 = Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
        [
          {:address=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1680794871, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>3},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>8},
        ]
      end

      spy3 = Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
        [
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>1, :action=>"lock", :lock_amount=>100, :timestamp=>1674194680, :block_number=>1},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>3, :action=>"lock", :lock_amount=>100, :timestamp=>1697229205, :block_number=>2},
        ]
      end

      spyTiersInfo = Spy.on_instance_method(RewardsService, :get_tiers).and_return do |networkId|
        [{
          max_amount: 0,
          multiplier: 1
        },
        {
          max_amount: 1000,
          multiplier: 1.3
        },
        {
          max_amount: 5000,
          multiplier: 1.5
        },
        {
          max_amount: 10000,
          multiplier: 1.7
        },
        {
          max_amount: 20000,
          multiplier: 2.1
        }
      ]
      end

      rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)
      assert_equal rewards, {"1"=>{"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61"=>0.40861513687600637, "0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A"=>0.5913848631239935}}

      spy1.unhook
      spy2.unhook
      spy3.unhook
      spyTiersInfo.unhook
    end
  end

  test "compute rewards no liquidity in some of the top market" do
    mock_enviroment(env:"production", partial_env_hash:mocked_env) do
      spy1 = Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
        assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

        if timestamp == 1688688000
          { blockNumber: 3 }
        elsif timestamp == 1689292800
          { blockNumber: 8 }
        end
      end

      spy2 = Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
        [
          {:address=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1680794871, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>9},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>9},
        ]
      end

      spy3 = Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
        [
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>1, :action=>"lock", :lock_amount=>100, :timestamp=>1674194680, :block_number=>1},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>3, :action=>"lock", :lock_amount=>100, :timestamp=>1697229205, :block_number=>2},
        ]
      end

      spyTiersInfo = Spy.on_instance_method(RewardsService, :get_tiers).and_return do |networkId|
        [{
          max_amount: 0,
          multiplier: 1
        },
        {
          max_amount: 1000,
          multiplier: 1.3
        },
        {
          max_amount: 5000,
          multiplier: 1.5
        },
        {
          max_amount: 10000,
          multiplier: 1.7
        },
        {
          max_amount: 20000,
          multiplier: 2.1
        }
      ]
      end

      rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)
      assert_equal rewards, {"1"=>{"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61"=>1.0}}

      spy1.unhook
      spy2.unhook
      spy3.unhook
      spyTiersInfo.unhook
    end
  end

  test "compute rewards no liquidity ever" do
    mock_enviroment(env:"production", partial_env_hash:mocked_env) do
      spy1 = Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
        assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

        if timestamp == 1688688000
          { blockNumber: 3 }
        elsif timestamp == 1689292800
          { blockNumber: 8 }
        end
      end

      spy2 = Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
        []
      end

      spy3 = Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
        [
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>1, :action=>"lock", :lock_amount=>100, :timestamp=>1674194680, :block_number=>1},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>3, :action=>"lock", :lock_amount=>100, :timestamp=>1697229205, :block_number=>2},
        ]
      end

      spyTiersInfo = Spy.on_instance_method(RewardsService, :get_tiers).and_return do |networkId|
        [{
          max_amount: 0,
          multiplier: 1
        },
        {
          max_amount: 1000,
          multiplier: 1.3
        },
        {
          max_amount: 5000,
          multiplier: 1.5
        },
        {
          max_amount: 10000,
          multiplier: 1.7
        },
        {
          max_amount: 20000,
          multiplier: 2.1
        }
      ]
      end

      rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)
      assert_equal rewards, {"1"=>{}}

      spy1.unhook
      spy2.unhook
      spy3.unhook
      spyTiersInfo.unhook
    end
  end

  test "compute rewards only one market with lock" do
    mock_enviroment(env:"production", partial_env_hash:mocked_env) do
      spy1 = Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
        assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

        if timestamp == 1688688000
          { blockNumber: 3 }
        elsif timestamp == 1689292800
          { blockNumber: 8 }
        end
      end

      spy2 = Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
        [
          {:address=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1680794871, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>2},
        ]
      end

      spy3 = Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
        [
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>1, :action=>"lock", :lock_amount=>100, :timestamp=>1674194680, :block_number=>9},
          {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>3, :action=>"lock", :lock_amount=>100, :timestamp=>1697229205, :block_number=>1},
        ]
      end

      spyTiersInfo = Spy.on_instance_method(RewardsService, :get_tiers).and_return do |networkId|
        [{
          max_amount: 0,
          multiplier: 1
        },
        {
          max_amount: 1000,
          multiplier: 1.3
        },
        {
          max_amount: 5000,
          multiplier: 1.5
        },
        {
          max_amount: 10000,
          multiplier: 1.7
        },
        {
          max_amount: 20000,
          multiplier: 2.1
        }
      ]
      end

      rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)
      assert_equal rewards, {"1"=>{"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A"=>1.0}}

      spy1.unhook
      spy2.unhook
      spy3.unhook
      spyTiersInfo.unhook
    end
  end

  test "compute rewards no lock ever" do
    mock_enviroment(env:"production", partial_env_hash:mocked_env) do
      spy1 = Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
        assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

        if timestamp == 1688688000
          { blockNumber: 3 }
        elsif timestamp == 1689292800
          { blockNumber: 8 }
        end
      end

      spy2 = Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
        [
          {:address=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1680794871, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>2},
          {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>2},
        ]
      end

      spy3 = Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
        [
        ]
      end

      spyTiersInfo = Spy.on_instance_method(RewardsService, :get_tiers).and_return do |networkId|
        [{
          max_amount: 0,
          multiplier: 1
        },
        {
          max_amount: 1000,
          multiplier: 1.3
        },
        {
          max_amount: 5000,
          multiplier: 1.5
        },
        {
          max_amount: 10000,
          multiplier: 1.7
        },
        {
          max_amount: 20000,
          multiplier: 2.1
        }
      ]
      end

      rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)
      assert_equal rewards, {"1"=>{}}

      spy1.unhook
      spy2.unhook
      spy3.unhook
      spyTiersInfo.unhook
    end
  end

end