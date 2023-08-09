module Api
  class BaseController < ActionController::API
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    # TODO: authentication

    def render_not_found
      render json: { error: 'Not Found' }, status: :not_found
    end

    def allowed_network?
      Rails.application.config_for(:ethereum).network_ids.include?(params[:network_id].to_s)
    end
  end
end
