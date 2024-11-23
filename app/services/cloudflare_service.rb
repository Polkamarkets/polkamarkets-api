require 'open-uri'

class CloudflareService
  attr_reader :api_token, :account_id

  def initialize
    @api_token = Rails.application.config_for(:cloudflare).api_token
    @account_id = Rails.application.config_for(:cloudflare).account_id

    raise "Cloudflare API token not found" if @api_token.nil?
    raise "Cloudflare account ID not found" if @account_id.nil?
  end

  def add_image_from_url(url)
    file = URI.open(url)
    add_image(file)
  end

  def cloudflare_id_from_image_url(url)
    # https://imagedelivery.net/YN1-rdnufJQJCgu3i1CbVw/5f7ecb7d-4a30-4a41-7381-a7777a540c00/public
    return nil unless url.include?('imagedelivery.net')

    url.split('/')[-2]
  end

  def add_image(file)
    uri = cloudflare_api_url + "images/v1"

    response = HTTP
      .headers("Authorization" => "Bearer #{api_token}")
      .post(uri, form: {
        file: HTTP::FormData::File.new(file),
        requireSignedURLs: false
      })

    unless response.status.success?
      raise "Cloudflare #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s)
  end

  def delete_image_from_url(image_url)
    image_id = cloudflare_id_from_image_url(image_url)
    return if image_id.blank?

    uri = cloudflare_api_url + "images/v1/#{image_id}"

    response = HTTP
      .headers("Authorization" => "Bearer #{api_token}")
      .delete(uri)

    unless response.status.success?
      raise "Cloudflare #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s)
  end

  private

  def cloudflare_api_url
    "https://api.cloudflare.com/client/v4/accounts/#{account_id}/"
  end
end
