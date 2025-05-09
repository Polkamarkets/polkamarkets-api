
class PrivyService
  attr_accessor :app_id, :app_secret

  def initialize
    @app_id = Rails.application.config_for(:privy).app_id
    @app_secret = Rails.application.config_for(:privy).app_secret
  end

  def get_user_data(user_id:)
    uri = privy_url + "/users/#{user_id}"

    response = HTTP.basic_auth(user: app_id, pass: app_secret)
      .headers('privy-app-id' => app_id)
      .get(uri)
    response_body = response.body.to_s

    raise "PrivyService :: Get User Data Error" unless response.status.success?

    data = parse_data(JSON.parse(response_body.to_s))

    return data if data[:login_type] != 'cross_app'

    cross_app_account_data = data[:linked_accounts].find { |account| account['type'] == 'cross_app' }

    return data if cross_app_account_data.blank?

    data[:address] = cross_app_account_data.dig("embedded_wallets")&.first&.dig("address")
    data
  end

  def search_users_by_wallet_address(wallet_address)
    uri = privy_url + "/users/wallet/address"

    response = HTTP.basic_auth(user: app_id, pass: app_secret)
      .headers('privy-app-id' => app_id)
      .headers('Content-Type' => 'application/json')
      .post(uri, json: {address: wallet_address})

    raise "PrivyService :: Search Users Error" unless response.status.success?

    JSON.parse(response.body.to_s)
  end

  def uid_from_linked_account_data(linked_account)
    case linked_account['type']
    when 'wallet'
      linked_account['address']
    when 'google_oauth'
      linked_account['email']
    when 'email'
      linked_account['address']
    when 'custom_auth'
      linked_account['custom_user_id']
    when 'cross_app'
      linked_account.dig("smart_wallets")&.first&.dig("address")
    else
      nil
    end
  end

  private

  def parse_data(privy_user_data)
    linked_accounts = privy_user_data["linked_accounts"]

    # Find the linked account with type 'wallet'
    wallet_account = linked_accounts.find { |account| account["type"] == "wallet" } || {}
    google_account = linked_accounts.find { |account| account["type"] == "google_oauth" } || {}
    email_account = linked_accounts.find { |account| account["type"] == "email" } || {}

    {
      login_type: linked_accounts[0]['type'],
      address: wallet_account['address'],
      email: email_account['address'] || google_account['email'],
      username: google_account['name'] || google_account['username'],
      avatar: google_account['profile_picture_url'],
      linked_accounts: linked_accounts
    }
  end

  def privy_url
    "https://auth.privy.io/api/v1"
  end
end
