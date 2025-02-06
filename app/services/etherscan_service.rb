class EtherscanService
  include BigNumberHelper

  attr_accessor :network_id

  def initialize(network_id)
    @network_id = network_id
  end

  def token_supply(contract_address)
    uri = etherscan_url + "/api?module=stats&action=tokensupply&contractaddress=#{contract_address}&apikey=#{api_key}"

    request_etherscan(uri).to_i
  end

  def contract_txs(contract_address)
    uri = etherscan_url + "/api?module=account&action=txlist&address=#{contract_address}&sort=desc&apikey=#{api_key}"

    request_etherscan(uri)
  end

  def token_transfers(contract_address)
    uri = etherscan_url + "/api?module=account&action=tokentx&contractaddress=#{contract_address}&sort=desc&apikey=#{api_key}"

    request_etherscan(uri)
  end

  def account_balance(address)
    uri = etherscan_url + "/api?module=account&action=balance&address=#{address}&tag=latest&apikey=#{api_key}"
    res = request_etherscan(uri, true)

    from_big_number_to_float(res)
  end

  def logs(contract_address, topics, from_block: nil, to_block: nil, fetch_all: false)
    uri = etherscan_url + "/api?module=logs&action=getLogs&address=#{contract_address}&apikey=#{api_key}"
    uri += "&fromBlock=#{from_block}" if from_block.present?
    uri += "&toBlock=#{to_block}" if to_block.present?

    topics.each_with_index do |topic, index|
      uri += "&topic#{index}=#{topic}" if topic.present?
    end

    logs = request_etherscan(uri)
    fetch_completed = fetch_all && logs.count == 1000
    return logs unless fetch_completed

    page = 1
    while fetch_completed
      page += 1
      # Etherscan rate limit is 5 requests per second
      sleep(0.2)
      response = request_etherscan(uri + "&page=#{page}&offset=1000")
      logs += response
      fetch_completed = response.count == 1000
    end

    logs
  end

  def latest_block_number(contract_address)
    contract_txs(contract_address).first['blockNumber'].to_i
  end

  def latest_block_number_by_network_id
    uri = etherscan_url + "/api?module=proxy&action=eth_blockNumber&apikey=#{api_key}"

    request_etherscan(uri, true).hex
  end

  private

  def request_etherscan(uri, as_string = false)
    response = HTTP.get(uri)

    unless response.status.success?
      raise "Etherscan #{response.status} :: #{response.body.to_s}"
    end

    result = JSON.parse(response.body.to_s)['result']

    if result.is_a?(String) && !as_string
      raise "Etherscan :: #{result}"
    end

    result
  end

  def etherscan_url
    @_etherscan_url ||=
      case network_id
      when 1
        'https://api.etherscan.io'
      when 100
        'https://api.gnosisscan.io'
      when 137
        'https://api.polygonscan.com'
      when 1284
        'https://api-moonbeam.moonscan.io'
      when 1285
        'https://api-moonriver.moonscan.io'
      when 42220
        'https://api.celoscan.io'
      when 44787
        'https://api-alfajores.celoscan.io'
      when 80001
        'https://api-mumbai.polygonscan.com'
      when 42161
        'https://api.arbiscan.io'
      when 421614
        'https://api-sepolia.arbiscan.io'
      else
        raise "EtherscanService :: Network #{network_id} unknown"
      end
  end

  def api_key
    @_api_key ||=
      case network_id
      when 1
        Rails.application.config_for(:etherscan).ethereum_api_key
      when 100
        Rails.application.config_for(:etherscan).gnosis_api_key
      when 137
        Rails.application.config_for(:etherscan).polygon_api_key
      when 1284
        Rails.application.config_for(:etherscan).moonbeam_api_key
      when 1285
        Rails.application.config_for(:etherscan).moonriver_api_key
      when 42220
        Rails.application.config_for(:etherscan).celo_api_key
      when 44787
        Rails.application.config_for(:etherscan).celo_api_key
      when 80001
        Rails.application.config_for(:etherscan).mumbai_api_key
      when 42161
        Rails.application.config_for(:etherscan).arbitrum_api_key
      when 421614
        "" # no API key required
      else
        raise "EtherscanService :: Network #{network_id} unknown"
      end
  end
end
