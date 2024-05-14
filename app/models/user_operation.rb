class UserOperation < ApplicationRecord
  include BigNumberHelper

  validates_presence_of :network_id, :user_address, :user_operation_hash, :user_operation, :user_operation_data

  before_validation :fill_user_address_from_user_operation

  enum status: {
    pending: 0,
    success: 1,
    failed: 2
  }

  EVENT_TOPIC = '0x49628fd1471006c1482da88028e9ce4dbb080b815c9b0344d39e5a8e6ec1419f'.freeze

  def fill_user_address_from_user_operation
    self.user_address ||= user_operation['sender'] if user_operation.present?
  end

  def market
    return @_market if @_market.present?

    return nil unless ['buy', 'sell', 'claimWinnings'].include?(user_operation_data.first['method'])

    eth_market_id = user_operation_data.first['arguments'].first

    @_market = Market.find_by(eth_market_id: eth_market_id, network_id: network_id)
  end

  def outcome
    return @_outcome if @_outcome.present?

    return nil unless market.present?

    @_outcome = market.outcomes.find_by(eth_market_id: user_operation_data.first['arguments'].second)
  end

  def market_title
    market&.title
  end

  def market_slug
    market&.slug
  end

  def outcome_title
    outcome&.title
  end

  def image_url
    outcome&.image_url || market&.image_url
  end

  def shares
    # TODO
    nil
  end

  def value
    case user_operation_data.first['method']
    when 'buy'
      from_big_number_to_float(user_operation_data.first['arguments'].fourth)
    when 'sell'
      from_big_number_to_float(user_operation_data.first['arguments'].third)
    else
      nil
    end
  end

  def action
    user_operation_data.first['method']
  end

  def timestamp
    created_at.to_i
  end

  def ticker
    # TODO: save in db
    if action == 'claimAndApproveTokens'
      # checking in useroperation if it's a fantasy token
      Rails.application.config_for(:ethereum).fantasy_tokens.each do |token|
        if user_operation.to_s.downcase.include?(token[2..-1].downcase)
          # fetching token symbol from smart contract
          return Rails.cache.fetch("fantasy_tokens:#{token}") do
            token_info = Bepro::Erc20ContractService.new(network_id: network_id, contract_address: token).token_info

            token_info[:symbol]
          end
        end
      end

      nil
    else
      market&.token&.dig(:symbol)
    end
  end

  def logs(paginate: false)
    @_logs ||=
      case network_id
      when 10200
        blockscout_logs(paginate: paginate)
      else
        etherscan_logs
      end
  end

  def logs_tx_hash
    return nil if logs.blank?

    case network_id
    when 10200
      logs.first['tx_hash']
    else
      logs.first['transactionHash']
    end
  end

  def etherscan_logs
    EtherscanService.new(network_id).logs(
      Rails.application.config_for(:ethereum).bundler_entry_point,
      [
        EVENT_TOPIC,
        user_operation_hash
      ]
    )
  end

  def blockscout_logs(paginate: false)
    all_logs = BlockscoutService.new(network_id).logs(
      Rails.application.config_for(:ethereum).bundler_entry_point,
      paginate: paginate
    )

    all_logs.select do |log|
      log['topics'].include?(EVENT_TOPIC) && log['topics'].include?(user_operation_hash)
    end
  end
end
