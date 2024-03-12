class Web3authJwtService
  def initialize
    raise 'Web3AuthJwt not configured' if web3auth_jwt_url.blank?
  end

  def get_user_token(user)

    # get user_id from user email, removing the domain
    user_id = user.email.split('@').first

    uri = web3auth_jwt_url + '/token'
    body = {
      user_id: user.slug,
      email: user.email,
      username: user.username,
      avatar_url: user.avatar,
    }

    Sentry.with_scope do |scope|
      scope.set_tags(
        uri: uri,
        body: body
      )

      begin
        response = HTTP.post(uri, json: body)
        response_body = response.body.to_s

        unless response.status.success?
          scope.set_tags(
            status: response.status,
            error: response_body.to_s
          )
          raise "Web3authJwtService :: Error"
        end

        response_json = JSON.parse(response_body.to_s)

        return response_json
      rescue => e
        scope.set_tags(
          error: e.message
        )
        raise "Web3authJwtService :: Error"
      end
    end
  end

  private

  def web3auth_jwt_url
    Rails.application.config_for(:ethereum).web3auth_jwt_url
  end
end