class IpfsService
  def self.image_url_from_hash(hash)
    return nil if hash.blank?

    Config.infura.ipfs_api_url + "cat?arg=#{hash}"
  end

  def add(file)
    uri = Config.infura.ipfs_api_url + 'add'

    response = HTTP
      .basic_auth(user: Config.infura.ipfs_project_id, pass: Config.infura.ipfs_project_secret)
      .post(uri, form: { data: HTTP::FormData::File.new(file) })

    unless response.status.success?
      raise "IpfsService #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s)
  end
end
