class BrevoService
  attr_accessor :api_key, :contact_list_id, :template_id, :invite_template_id, :redirection_url, :sender_id

  def initialize
    @api_key = Rails.application.config_for(:brevo).api_key
    @contact_list_id = Rails.application.config_for(:brevo).contact_list_id
    @template_id = Rails.application.config_for(:brevo).template_id
    @invite_template_id = Rails.application.config_for(:brevo).invite_template_id
    @redirection_url = Rails.application.config_for(:brevo).redirection_url
    @sender_id = Rails.application.config_for(:brevo).sender_id

    raise 'BrevoService :: API Key not found' if @api_key.blank?
    raise 'BrevoService :: Contact List not found' if @contact_list_id.blank?
    raise 'BrevoService :: Template ID not found' if @template_id.blank?
    raise 'BrevoService :: Redirection URL not found' if @redirection_url.blank?
  end

  def get_contact(email:)
    raise 'BrevoService :: Email not found' if email.blank?

    uri = "#{base_uri}/contacts/#{email}"

    request_get_brevo(uri)
  end

  def get_all_contacts
    uri = "#{base_uri}/contacts?limit=1000"

    response = request_get_brevo(uri)

    response['contacts']
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

    request_post_brevo(uri, body)
  end

  def register_contact_without_optin(email:, name: nil, redeem_code: nil)
    raise 'BrevoService :: Email not found' if email.blank?

    uri = "#{base_uri}/contacts"
    body = {
      "attributes" => {
        'FULLNAME' => name,
        'REDEEMCODE' => redeem_code
      },
      "email" => email,
      "listIds" => [contact_list_id],
      "updateEnabled" => true
    }

    request_post_brevo(uri, body)
  end

  def sync_contact_redeem_code(brevo_contact)
    return if brevo_contact.blank? || brevo_contact.dig('email').blank?

    email = brevo_contact.dig('email')
    redeem_code = brevo_contact.dig('attributes', 'REDEEMCODE')

    user = User.find_by(email: email)

    if user.blank?
      if redeem_code.blank?
        user = User.create!(email: email)
        register_contact_without_optin(email: user.email, redeem_code: user.redeem_code)
      else
        user = User.create!(email: email, redeem_code: redeem_code)
      end
    else
      if redeem_code.blank?
        user.generate_redeem_code if user.redeem_code.blank?
        register_contact_without_optin(email: user.email, redeem_code: user.redeem_code)
      else
        user.redeem_code = redeem_code
        user.save!
      end
    end
  end

  def send_invitation(email:, name: nil)
    raise 'BrevoService :: Email not found' if email.blank?
    raise 'BrevoService :: Invite Template ID not found' if invite_template_id.blank?

    user = User.find_by(email: email)

    if user.blank?
      # creating and registering user on brevo
      user = User.create!(email: email, username: name)
      sleep(5) # waiting for brevo to register the user before sending the email
    else
      # ensuring user has a redeem code
      if user.redeem_code.blank?
        user.generate_redeem_code
        user.save!
      end

      # ensuring user is in brevo contact list
      begin
        contact = get_contact(email: email)
        # triggering contact register if contact does not have redeem code
        raise 'BrevoService :: Redeem Code not present' if contact.dig('attributes', 'REDEEMCODE').blank?
      rescue
        register_contact_without_optin(email: user.email, name: user.username, redeem_code: user.redeem_code)
        sleep(1) # waiting for brevo to update the user before sending the email
      end
    end

    uri = "#{base_uri}/smtp/email"
    body = {
      "templateId" => invite_template_id,
      "to" => [
        { 'email' => email }
      ]
    }

    request_post_brevo(uri, body)
  end

  def send_raw_email(email:, subject:, html_content:, custom_sender_id: nil)
    uri = "#{base_uri}/smtp/email"
    body = {
      "subject" => subject,
      "htmlContent" => html_content,
      "to" => [
        { 'email' => email }
      ],
      "sender": { 'id' => custom_sender_id || sender_id }
    }

    request_post_brevo(uri, body)
  end

  private

  def request_get_brevo(uri)
    headers = {
      'api-key' => api_key,
      'Content-Type' => 'application/json'
    }

    response = HTTP.headers(headers).get(uri)

    unless response.status.success?
      raise "Brevo #{response.status} :: #{response.body.to_s}"
    end

    JSON.parse(response.body.to_s)
  end

  def request_post_brevo(uri, body)
    headers = {
      'api-key' => api_key,
      'Content-Type' => 'application/json'
    }

    response = HTTP.headers(headers).post(uri, json: body)

    unless response.status.success?
      raise "Brevo #{response.status} :: #{response.body.to_s}"
    end

    return true if response.body.to_s.blank?

    JSON.parse(response.body.to_s)
  end

  def base_uri
    @_brevo_url ||= 'https://api.brevo.com/v3'
  end
end
