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

  private

  def cloudflare_api_url
    "https://api.cloudflare.com/client/v4/accounts/#{account_id}/"
  end
end
