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
              jwks: fetch_jwks(),
            )
          rescue JWT::ExpiredSignature, JWT::VerificationError, JWT::DecodeError
            return head :unauthorized
          end

          privy_service = PrivyService.new
          privy_user_data = privy_service.get_user_data(user_id: jwt_payload[0]['sub'])

          email = privy_user_data[:email] || privy_user_data[:username] || privy_user_data[:address] + '@login_type.com'
          username = privy_user_data[:username]
          avatar = privy_user_data[:avatar]
          raw_email = privy_user_data[:email]
          login_public_key = privy_user_data[:address]
          login_type = privy_user_data[:login_type]

          user = User.find_by(email: email)

          if user.nil?
            user = User.new(email: email, login_public_key: login_public_key, raw_email: raw_email, username: username)
            user.save!
          else
            user.update(login_public_key: login_public_key, raw_email: raw_email, username: username || user.username)
          end

          user.update(username: email.split('@').first) if user.username.blank?
          user.update(avatar: avatar) if avatar.present?
          user.update(login_type: login_type) if login_type.present?

          @current_user_id = user.id
        end
      end
    end

    def fetch_jwks()
      response = HTTP.get(Rails.application.config_for(:privy).jwks_url)

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

    def allowed_network?
      Rails.application.config_for(:ethereum).network_ids.include?(params[:network_id].to_s)
    end
  end
end
