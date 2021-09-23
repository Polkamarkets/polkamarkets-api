class BeproService
  PREDICTION_MARKET_CONTRACT = 'predictionMarket'.freeze
  ERC20_CONTRACT = 'erc20'.freeze
  REALITIO_CONTRACT = 'realitio'.freeze

  attr_accessor :contract_name, :contract_address

  def self.prediction_market
    new(contract_name: PREDICTION_MARKET_CONTRACT, contract_address: Config.ethereum.contract_address)
  end

  def self.erc20
    new(contract_name: ERC20_CONTRACT, contract_address: Config.ethereum.erc20_contract_address)
  end

  def self.realitio
    new(contract_name: REALITIO_CONTRACT, contract_address: Config.ethereum.realitio_contract_address)
  end

  def initialize(contract_name:, contract_address:)
    @contract_name = contract_name
    @contract_address = contract_address
  end

  def call(method:, args: [])
    if args.kind_of?(Array)
      args = args.compact.join(',')
    end

    uri = Config.bepro.api_url + "/call?contract=#{contract_name}&address=#{contract_address}&method=#{method}"
    uri << "&args=#{args}" if args.present?

    response = HTTP.get(uri)

    unless response.status.success?
      raise "BeproService #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s)
  end

  def get_events(event_name:, filter: {})
    uri = Config.bepro.api_url + "/events?contract=#{contract_name}&address=#{contract_address}&eventName=#{event_name}"
    uri << "&filter=#{filter.to_json}" if filter.present?

    response = HTTP.get(uri)

    unless response.status.success?
      raise "BeproService #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s)
  end
end
