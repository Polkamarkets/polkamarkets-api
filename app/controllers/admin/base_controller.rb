module Admin
  class BaseController < ApplicationController
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include ActionController::HttpAuthentication::Token::ControllerMethods

    # TODO: move to devise
    before_action :authenticate!, if: -> { !Rails.env.development? }

    def authenticate!
      authenticate_or_request_with_http_basic do |username, password|
        # TODO: Check origin
        username == ENV['ADMIN_USERNAME'] && password == ENV['ADMIN_PASSWORD']
      end
    end
  end
end
