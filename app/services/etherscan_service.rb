class EtherscanService
  attr_accessor :chain

  def initialize(chain = 'mainnet')
    @chain = chain
  end

  def block_number_by_timestamp(timestamp)
    uri = etherscan_url + "/api?module=block&action=getblocknobytime&timestamp=#{timestamp}&closest=before&apikey=#{api_key}"

    request_etherscan(uri)
  end

  private

  def request_etherscan(uri)
    response = HTTP.get(uri)

    unless response.status.success?
      raise "Etherscan #{response.status} :: #{response.body.to_s}"
    end

    result = JSON.parse(response.body.to_s)['result']

    if result.is_a?(String)
      raise "Etherscan :: #{result}"
    end

    result
  end

  def etherscan_url
    @_etherscan_url ||=
      case chain
      when 'mainnet'
        'https://api.etherscan.io'
      when 'goerli'
        'https://api-goerly.etherscan.io'
      when 'polygon'
        'https://api.polygonscan.com'
      when 'blockscout'
        'http://localhost:4010'
      else
        raise "EtherscanService :: Chain #{chain} unknown"
      end
  end

  def api_key
    @_api_key ||=
      case chain
      when 'mainnet', 'rinkeby'
        Rails.application.config_for(:etherscan).api_key
      when 'polygon'
        Rails.application.config_for(:etherscan).polygon_api_key
      when 'blockscout'
        'dummy_api_key'
      else
        raise "EtherscanService :: Chain #{chain} unknown"
      end
  end
end
