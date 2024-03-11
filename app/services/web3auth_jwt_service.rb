class Web3authJwtService
  def initialize
    raise 'Web3AuthJwt not configured' if web3auth_jwt_url.blank?
  end

  def sign_user_operation(user_operation)

    return if user_operation.user_method_call_data.blank?

    # get user from table using user_operation['user_address']
    user = User.find_by(wallet_address: user_operation.user_address)

    # if user is not found, return
    return if user.blank?

    # get user_id from user email, removing the domain
    user_id = user.email.split('@').first

    uri = web3auth_jwt_url + "/sign/transaction"
    body = {
      user_id: user_id,
      chain_id: user_operation.network_id,
      to_address: user_operation.user_address,
      method_call_data: user_operation.user_method_call_data
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

        user_operation.update(user_operation: response_json["user_operation"], user_operation_hash_final: response_json["user_operation_hash_final"])

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
