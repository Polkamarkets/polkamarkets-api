require "test_helper"

class RewardServiceTest < ActiveSupport::TestCase
  test "compute rewards simple case 50%" do

    Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
      assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

      if timestamp == 1688688000
        { blockNumber: 3 }
      elsif timestamp == 1689292800
        { blockNumber: 8 }
      end
    end

    Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
      [
        {:address=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1680794871, :block_number=>2},
        {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>3},
        {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>2, :action=>"add_liquidity", :shares=>2000, :timestamp=>1673337153, :block_number=>3},
      ]
    end

    Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
      [
        {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>1, :action=>"lock", :lock_amount=>100, :timestamp=>1674194680, :block_number=>1},
        {:user=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :item_id=>1, :action=>"lock", :lock_amount=>200, :timestamp=>1695431077, :block_number=>2},
        {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>3, :action=>"lock", :lock_amount=>100, :timestamp=>1697229205, :block_number=>3},
        {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>2, :action=>"lock", :lock_amount=>50, :timestamp=>1697229205, :block_number=>1},
      ]
    end

    rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)
    assert_equal rewards, {1=>{"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A"=>0.5, "0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61"=>0.5}}
  end

  test "compute rewards simple case with multiplier" do

    Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
      assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

      if timestamp == 1688688000
        { blockNumber: 3 }
      elsif timestamp == 1689292800
        { blockNumber: 8 }
      end
    end

    Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
      [
        {:address=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1680794871, :block_number=>2},
        {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>2},
      ]
    end

    Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
      [
        {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>1, :action=>"lock", :lock_amount=>100, :timestamp=>1674194680, :block_number=>1},
        {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>3, :action=>"lock", :lock_amount=>100, :timestamp=>1697229205, :block_number=>2},
      ]
    end

    rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)
    assert_equal rewards, {1=>{"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61"=>0.4347826086956521, "0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A"=>0.5652173913043478}}
  end

  test "compute rewards top changing" do

    Spy.on_instance_method(EtherscanService, :block_number_by_timestamp).and_return do |timestamp|
      assert timestamp == 1688688000 || timestamp == 1689292800, "Timestamp invalid"

      if timestamp == 1688688000
        { blockNumber: 3 }
      elsif timestamp == 1689292800
        { blockNumber: 8 }
      end
    end

    Spy.on_instance_method(RewardsService, :network_actions).and_return do |networkId|
      [
        {:address=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :market_id=>1, :action=>"add_liquidity", :shares=>200, :timestamp=>1680794871, :block_number=>2},
        {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>3, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>2},
        {:address=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :market_id=>2, :action=>"add_liquidity", :shares=>200, :timestamp=>1673337153, :block_number=>4},
      ]
    end

    Spy.on_instance_method(RewardsService, :network_locks).and_return do |networkId|
      [
        {:user=>"0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61", :item_id=>1, :action=>"lock", :lock_amount=>100, :timestamp=>1674194680, :block_number=>1},
        {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>3, :action=>"lock", :lock_amount=>200, :timestamp=>1697229205, :block_number=>3},
        {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>2, :action=>"lock", :lock_amount=>300, :timestamp=>1697229205, :block_number=>5},
        {:user=>"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A", :item_id=>2, :action=>"unlock", :lock_amount=>300, :timestamp=>1697229205, :block_number=>9},
      ]
    end

    rewards = RewardsService.new.get_rewards(date: Date.new(2023, 7, 17), top: 2)

    assert_equal rewards, {1=>{"0xEF4D8DC13FDEB0F2B4784B1DAE743093C228A08A"=>0.8333333333333333, "0x6122252DC9BE4DBF4DF78C22E5348A12B1C77D61"=>0.16666666666666666}}
  end

end