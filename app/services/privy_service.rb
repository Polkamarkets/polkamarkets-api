
class PrivyService
  attr_accessor :api_url, :app_id, :app_secret

  def initialize
    @api_url = Rails.application.config_for(:privy).api_url
    @app_id = Rails.application.config_for(:privy).app_id
    @app_secret = Rails.application.config_for(:privy).app_secret
  end

  def get_user_data(user_id:)
      uri = api_url + "/api/v1/users/#{user_id}"

      Sentry.with_scope do |scope|
        scope.set_tags(
          uri: uri
        )

        begin
          response = HTTP.basic_auth(user: app_id, pass: app_secret)
               .headers('privy-app-id' => app_id)
               .get(uri)
          response_body = response.body.to_s

          unless response.status.success? && !response_body.include?('server unavailable')
            puts response_body.to_s
            scope.set_tags(
              status: response.status,
              error: response_body.to_s
            )
            raise "PrivyService :: Get User Data Error"
          end

          parse_data(JSON.parse(response_body.to_s))
        rescue => e
          scope.set_tags(
            error: e.message
          )
          raise e.message
        end
      end
  end

  private

  def parse_data(privy_user_data)
    linked_accounts = privy_user_data["linked_accounts"]

    # Find the linked account with type 'wallet'
    wallet_account = linked_accounts.find { |account| account["type"] == "wallet" } || {}
    twitter_account = linked_accounts.find { |account| account["type"] == "twitter_oauth" } || {}
    google_account = linked_accounts.find { |account| account["type"] == "google_oauth" } || {}
    email_account = linked_accounts.find { |account| account["type"] == "email" } || {}


    {
      login_type: linked_accounts[0]['type'],
      address: wallet_account['address'],
      email: email_account['address'] || google_account['email'] || twitter_account['email'],
      username: google_account['name'] || twitter_account['name'] || google_account['username'] || twitter_account['username'],
      avatar: google_account['profile_picture_url'] || twitter_account['profile_picture_url']
    }
  end

end
