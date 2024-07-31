module Api
  class BaseController < ActionController::API
    include ApplicationHelper

    include ActionController::HttpAuthentication::Token::ControllerMethods

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    # TODO: authentication

    def render_not_found
      render json: { error: 'Not Found' }, status: :not_found
    end

    private

    def authenticate_user
      if params[:legacy].present?
        return authenticate_user_legacy
      end

      if request.headers['Authorization'].present?
        authenticate_or_request_with_http_token do |token|
          jwt_payload = nil

          begin
            jwt_payload = JWT.decode(
              token,
              nil,
              true, # Verify the signature of this token
              algorithms: ["ES256"],
              jwks: fetch_jwks(Rails.application.config_for(:privy).jwks_url),
            )
          rescue JWT::ExpiredSignature, JWT::VerificationError, JWT::DecodeError
            # should be non-blocking
            return
          end

          privy_user_id = jwt_payload[0]['sub']
          privy_user_data = PrivyService.new.get_user_data(user_id: privy_user_id)

          email = privy_user_data[:email] || privy_user_data[:username] || privy_user_data[:address] + '@login_type.com'
          username =
            privy_user_data[:username] || (privy_user_data[:email].present? ? email.split('@').first : "User #{privy_user_data[:address][0..4]}...#{privy_user_data[:address][-3..-1]}")
          slug =
            (privy_user_data[:username] || privy_user_data[:email].present?) ? nil : "user-#{privy_user_data[:address][2..4]}#{privy_user_data[:address][-3..-1]}".downcase
          avatar = privy_user_data[:avatar]
          raw_email = privy_user_data[:email]
          login_public_key = privy_user_data[:address]
          login_type = privy_user_data[:login_type]

          user = User.find_by(email: email) || User.find_by(login_public_key: login_public_key)

          if user.nil?
            user = User.new(email: email, login_public_key: login_public_key, raw_email: raw_email, username: username, slug: slug, idp_uid: privy_user_id, idp: 'privy')
            user.save!
          else
            user.update(login_public_key: login_public_key, raw_email: raw_email, email: email, idp_uid: privy_user_id, idp: 'privy')
          end

          # updating user idps
          privy_user_data[:linked_accounts].each do |linked_account|
            idp_uid = PrivyService.new.uid_from_linked_account_data(linked_account)
            user_idp = user.user_idps.find_or_initialize_by(provider: linked_account['type'], uid: idp_uid)
            user_idp.data = linked_account
            user_idp.save!
          end

          if params[:redeem_code].present? && !user.whitelisted?
            # checking for tournament group with redeem code
            tournament_group = TournamentGroup.find_by(redeem_code: params[:redeem_code])

            if tournament_group.present?
              user.update(whitelisted: true, redeem_code: params[:redeem_code])
            end
          end

          user.update(username: username) if user.username.blank?
          user.update(avatar: avatar) if avatar.present? && user.avatar.blank?
          user.update(login_type: login_type) if login_type.present?

          @current_user_id = user.id
        end
      end
    end

    def authenticate_user_legacy
      if request.headers['Authorization'].present?
        authenticate_or_request_with_http_token do |token|
          jwt_payload = nil
          jwt_user_data = nil

          legacy_jwks_providers.each_with_index do |jwks_provider, index|
            begin
              jwt_payload = JWT.decode(
                token,
                nil,
                true, # Verify the signature of this token
                algorithms: ["ES256"],
                jwks: fetch_jwks(jwks_provider),
              )
            rescue JWT::ExpiredSignature, JWT::VerificationError, JWT::DecodeError
              return head :unauthorized if index == jwks_providers.length - 1
            end

            break if jwt_payload
          end

          begin
            jwt_user_data = JWT.decode(
              params[:oauth_access_token],
              nil,
              false,
              algorithms: ["RS256"],
            )
          rescue JWT::ExpiredSignature, JWT::VerificationError, JWT::DecodeError
            # should be non-blocking
            # TODO: remove after full migration to new auth
          end

          if jwt_payload[0]['email'].blank? && jwt_user_data.present?
            email = jwt_user_data[0]['email']
          else
            email = normalize_email(jwt_payload[0]['email'])
          end

          username = jwt_user_data[0]['username'] if jwt_user_data.present?
          avatar = jwt_user_data[0]['avatar_url'] if jwt_user_data.present?
          raw_email = jwt_payload[0]['email']
          login_public_key = jwt_payload[0]['wallets'][0]['address'] || jwt_payload[0]['wallets'][0]['public_key']

          user = User.find_by(email: email)

          if user.nil?
            user = User.new(email: email, login_public_key: login_public_key, raw_email: raw_email, username: username)
            user.save!
          else
            user.update(login_public_key: login_public_key, raw_email: raw_email, username: username || user.username)
          end

          user.update(username: email.split('@').first) if user.username.blank?
          user.update(avatar: avatar) if avatar.present?

          @current_user_id = user.id
        end
      end
    end

    def fetch_jwks(url)
      response = HTTP.get(url)

      if response.code == 200
        JSON.parse(response.body.to_s)
      end
    end

    def legacy_jwks_providers
      [
        'https://authjs.web3auth.io/jwks',
        'https://api.openlogin.com/jwks',
      ].compact
    end

    def authenticate_user!(options = {})
      authenticate_user

      head :unauthorized unless signed_in?
    end

    def current_user
      if @current_user_id
        @current_user ||= User.find(@current_user_id)
      end
    end

    def signed_in?
      @current_user_id.present?
    end

    def user_from_username
      @_user_from_username ||=
        User.where(
          'lower(slug) = ? OR lower(username) = ? OR lower(wallet_address) = ?',
          params[:id].to_s.downcase,
          params[:id].to_s.downcase,
          params[:id].to_s.downcase
        ).first
    end

    def address_from_username
      @_address_from_username ||= user_from_username&.wallet_address&.downcase
    end

    def serializable_scope
      return User.find_by(id: params[:requester_id]) if params[:requester_id]

      current_user
    end

    def allowed_network?
      Rails.application.config_for(:ethereum).network_ids.include?(params[:network_id].to_s)
    end
  end
end
