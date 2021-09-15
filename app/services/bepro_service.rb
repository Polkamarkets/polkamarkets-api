class BeproService
  PREDICTION_MARKET_CONTRACT = 'predictionMarket'.freeze
  ERC20_CONTRACT = 'erc20'.freeze
  REALITIO_CONTRACT = 'realitio'.freeze

  def self.prediction_market(method:, args:) 
    call(contract: PREDICTION_MARKET_CONTRACT, method: method, args: args)
  end

  def self.erc20(method:, args:) 
    call(contract: ERC20_CONTRACT, method: method, args: args)
  end

  def self.realitio(method:, args:) 
    call(contract: REALITIO_CONTRACT, method: method, args: args)
  end

  def self.call(contract:, method:, args:)
    if args.kind_of?(Array)
      args = args.compact.join(',')
    end

    uri = Config.bepro.bepro_api_url + "call?contract=#{contract}&method=#{method}"
    uri = Config.bepro.bepro_api_url + "call?contract=#{contract}&method=#{method}&args=#{args}" if args.present?

    response = HTTP.get(uri)

    unless response.status.success?
      raise "BeproService #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s)
  end
end
