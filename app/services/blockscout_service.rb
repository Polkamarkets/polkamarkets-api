class BlockscoutService
  attr_accessor :network_id

  def initialize(network_id)
    @network_id = network_id
  end

  def logs(contract_address, paginate: false)
    base_uri = blockscout_url + "/addresses/#{contract_address}/logs"

    all_logs = []

    res = request_blockscout(base_uri)

    all_logs += res['items']

    while res['next_page_params'].present? && paginate
      uri = base_uri + "?#{res['next_page_params'].to_query}"
      res = request_blockscout(uri)
      all_logs += res['items']
    end

    all_logs
  end

  private

  def request_blockscout(uri)
    response = HTTP.get(uri)

    unless response.status.success?
      raise "Blockscout #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s)
  end

  def blockscout_url
    @_blockscout_url ||=
      case network_id
      when 10200
        'https://gnosis-chiado.blockscout.com/api/v2'
      else
        raise "BlockscoutService :: Network #{network_id} unknown"
      end
  end
end
