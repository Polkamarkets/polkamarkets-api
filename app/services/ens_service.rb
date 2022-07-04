class EnsService
  def get_ens_domain(address:, refresh: false)
    Rails.cache.fetch("ens:#{address.downcase}", force: refresh) do
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
end
