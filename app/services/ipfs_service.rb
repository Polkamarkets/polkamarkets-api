require 'open-uri'

class IpfsService
  def self.image_url_from_hash(hash)
    return nil if hash.blank?

    # Rails.application.config_for(:infura).ipfs_api_url + "cat?arg=#{hash}"
    # Infura URL changed to POST request, changing to direct ipfs request
    hosting_url + hash
  end

  def self.hosting_url
    Rails.application.config_for(:infura).ipfs_project_gateway || "https://infura-ipfs.io/ipfs/"
  end

  def self.ipfs_hash_from_url(url)
    url.split('/').last
  end

  def self.is_ipfs_hash?(url)
    # fetching last part of url
    hash = ipfs_hash_from_url(url)

    hash.length == 46 && hash.start_with?('Qm')
  end

  def self.get_ipfs_file_size(hash)
    uri = hosting_url + hash

    response = HTTP.get(uri)

    unless response.status.success?
      raise "IpfsService #{response.status} :: #{response.body.to_s}"
    end

    response.body.to_s.length
  end

  def add_from_url(url)
    file = URI.open(url)
    add(file)
  end

  def add(file)
    uri = Rails.application.config_for(:infura).ipfs_api_url + 'add'

    response = HTTP
      .basic_auth(user: Rails.application.config_for(:infura).ipfs_project_id, pass: Rails.application.config_for(:infura).ipfs_project_secret)
      .post(uri, form: { data: HTTP::FormData::File.new(file) })

    unless response.status.success?
      raise "IpfsService #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s)
  end
end
