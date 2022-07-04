class EnsService
  def get_ens_domain(address)
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

  def ens_etherscan_url
    @_ens_etherscan_url ||= 'https://etherscan.io/enslookup-search?search='
  end
end
