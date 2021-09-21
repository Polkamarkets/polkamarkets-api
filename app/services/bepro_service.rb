class BeproService
  PREDICTION_MARKET_CONTRACT = 'predictionMarket'.freeze
  ERC20_CONTRACT = 'erc20'.freeze
  REALITIO_CONTRACT = 'realitio'.freeze

  def self.prediction_market
    new(contract_name: PREDICTION_MARKET_CONTRACT)
  end 

  def self.erc20
    new(contract_name: ERC20_CONTRACT)
  end

  def self.realitio
    new(contract_name: REALITIO_CONTRACT)
  end

  def initialize(contract_name:)
    @contract_name = contract_name
  end

  def call(method:, args:)
    if args.kind_of?(Array)
      args = args.compact.join(',')
    end

    uri = Config.bepro.bepro_api_url + "call?contract=#{@contract_name}&method=#{method}"
    uri = Config.bepro.bepro_api_url + "call?contract=#{@contract_name}&method=#{method}&args=#{args}" if args.present?

    response = HTTP.get(uri)

    unless response.status.success?
      raise "BeproService #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s)
  end

  def get_events(event_name:, args:)
    if args.kind_of?(Array)
      args = args.compact.join(',')
    end

    uri = Config.bepro.bepro_api_url + "events?contract=#{@contract_name}&eventName=#{event_name}"
    uri = Config.bepro.bepro_api_url + "events?contract=#{@contract_name}&eventName=#{event_name}&args=#{args}" if args.present?

    response = HTTP.get(uri)

    unless response.status.success?
      raise "BeproService #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s)
  end
end