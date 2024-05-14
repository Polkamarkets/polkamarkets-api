class BrevoService
  attr_accessor :api_key, :contact_list_id, :template_id, :redirection_url

  def initialize
    @api_key = Rails.application.config_for(:brevo).api_key
    @contact_list_id = Rails.application.config_for(:brevo).contact_list_id
    @template_id = Rails.application.config_for(:brevo).template_id
    @redirection_url = Rails.application.config_for(:brevo).redirection_url

    raise 'BrevoService :: API Key not found' if @api_key.blank?
    raise 'BrevoService :: Contact List not found' if @contact_list_id.blank?
    raise 'BrevoService :: Template ID not found' if @template_id.blank?
    raise 'BrevoService :: Redirection URL not found' if @redirection_url.blank?
  end

  def register_contact(email:, name:, redeem_code:)
    raise 'BrevoService :: Email not found' if email.blank?

    uri = "#{base_uri}/contacts/doubleOptinConfirmation"
    body = {
      "attributes" => {
        'FULLNAME' => name,
        'REDEEMCODE' => redeem_code
      },
      "email" => email,
      "includeListIds" => [contact_list_id],
      "redirectionUrl" => redirection_url,
      "templateId" => template_id
    }

    request_brevo(uri, body)
  end

  private

  def request_brevo(uri, body)
    headers = {
      'api-key' => api_key,
      'Content-Type' => 'application/json'
    }

    response = HTTP.headers(headers).post(uri, json: body)

    unless response.status.success?
      raise "Brevo #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s)
  end

  def base_uri
    @_brevo_url ||= 'https://api.brevo.com/v3'
  end
end
