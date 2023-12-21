module Api
  class BaseController < ActionController::API
    include ApplicationHelper

    include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :authenticate_user

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    # TODO: authentication

    def render_not_found
      render json: { error: 'Not Found' }, status: :not_found
    end

    private

    def authenticate_user
      if request.headers['Authorization'].present?
        authenticate_or_request_with_http_token do |token|
          jwt_payload = nil

          begin
            jwt_payload = JWT.decode(
              token,
              nil,
              true, # Verify the signature of this token
              algorithms: ["ES256"],
              jwks: fetch_jwks_pnp,
            )
          rescue JWT::ExpiredSignature, JWT::VerificationError, JWT::DecodeError

          end

          begin
            jwt_payload = JWT.decode(
              token,
              nil,
              true, # Verify the signature of this token
              algorithms: ["ES256"],
              jwks: fetch_jwks_core_kit,
            )
          rescue JWT::ExpiredSignature, JWT::VerificationError, JWT::DecodeError
            head :unauthorized
          end

          jwt_user_data = JWT.decode(
            params[:oauth_access_token],
            nil,
            false,
            algorithms: ["RS256"],
          )

          if jwt_payload[0]['email'].blank?
            email = jwt_user_data[0]['email']
          else
            email = normalize_email(jwt_payload[0]['email'])
          end

          username = jwt_user_data[0]['username']
          raw_email = jwt_payload[0]['email']
          login_public_key = jwt_payload[0]['wallets'][0]['address']

          user = User.find_by(email: email)

          if user.nil?
            user = User.new(email: email, login_public_key: login_public_key, raw_email: raw_email, username: username)
            user.save!
          else
            user.update(login_public_key: login_public_key, raw_email: raw_email, username: username)
          end

          user.update(username: email.split('@').first) if user.username.blank?

          @current_user_id = user.id

        end
      end
    end

    def fetch_jwks_pnp
      response = HTTP.get('https://api.openlogin.com/jwks')

      if response.code == 200
        JSON.parse(response.body.to_s)
      end
    end

    def fetch_jwks_core_kit
      response = HTTP.get('https://authjs.web3auth.io/jwks')
      if response.code == 200
        JSON.parse(response.body.to_s)
      end
    end

    def authenticate_user!(options = {})
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

    def address_from_username
      @_address_from_username ||= User.where('lower(username) = ?', params[:id].to_s.downcase).first&.wallet_address&.downcase
    end

    def allowed_network?
      Rails.application.config_for(:ethereum).network_ids.include?(params[:network_id].to_s)
    end
  end
end
