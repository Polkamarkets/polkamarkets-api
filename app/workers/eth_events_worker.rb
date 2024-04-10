class EthEventsWorker
  include Sidekiq::Worker

  def perform(network_id, contract_name, contract_address, api_url, event_name, filter)
    Bepro::SmartContractService.new(
      network_id: network_id,
      contract_name: contract_name,
      contract_address: contract_address,
      api_url: api_url
    ).get_events(
      event_name: event_name,
      filter: filter,
      store_events: true
    )
  end
end
