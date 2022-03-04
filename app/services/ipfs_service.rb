class IpfsService
  def self.image_url_from_hash(hash)
    return nil if hash.blank?

    # Rails.application.config_for(:infura).ipfs_api_url + "cat?arg=#{hash}"
    # Infura URL changed to POST request, changing to direct ipfs request
    "https://ipfs.io/ipfs/#{hash}"
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
