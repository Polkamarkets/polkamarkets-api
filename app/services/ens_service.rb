class EnsService
  def get_ens_domains(address:)
    response = HTTP.post('https://api.thegraph.com/subgraphs/name/ensdomains/ens', body: "{
      \"operationName\":\"getNamesFromSubgraph\",
      \"variables\":{\"address\":\"#{address.downcase}\"},
      \"query\":\"query getNamesFromSubgraph($address: String\u0021) {domains(first: 1000, where: {resolvedAddress: $address}) {name resolver isMigrated createdAt __typename } }\"
    }")

    unless response.status.success?
      raise "EnsService #{response.status} :: #{response.body.to_s}"
    end

    domains = JSON.parse(response.body.to_s)['data']['domains']
  end

  def get_ens_domain(address:, refresh: false)
    Rails.cache.fetch("ens:#{address.downcase}", force: refresh) do
      # fetching domains from subgraph
      domains = get_ens_domains(address: address)

      # if no domains are found, we return nil
      next nil if domains.blank?

      # if only one domain is found, we return it
      next domains.first['name'] if domains.count == 1

      # if more than one domain is found, we fetch the resolved domain via etherscan
      uri = ens_etherscan_url + address

      response = HTTP.get(uri)

      unless response.status.success?
        raise "EnsService #{response.status} :: #{response.body.to_s}"
      end

      html = Nokogiri::HTML(response.body.to_s)

      domains = html
        .search('.mb-5-alt')
        .search('a')
        .select { |a| a.values.any? { |v| v.include?('enslookup-search') } }
        .map { |v| v.text }

      domains.first
    end
  end

  def cached_ens_domain(address:)
    # only performing a read from cache, not fetching it in case it's not present
    Rails.cache.read("ens:#{address.downcase}")
  end

  def ens_etherscan_url
    @_ens_etherscan_url ||= 'https://etherscan.io/enslookup-search?search='
  end

  def ens_subgraph_url
    @_ens_subgraph_url ||= 'https://api.thegraph.com/subgraphs/name/ensdomains/ens'
  end
end
