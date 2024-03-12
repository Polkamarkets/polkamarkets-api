class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token

  def google_oauth2
      # You need to implement the method below in your model (e.g. app/models/user.rb)
      puts "request.env['omniauth.auth'] is: #{request.env['omniauth.auth']}"
      @user = User.from_omniauth(request.env['omniauth.auth'])

      # render json:
      #     request.env['omniauth.auth'], status: :created
      if @user.persisted?

        # call jwt login and return to frontend
        jwt_service = Web3authJwtService.new
        jwt_response = jwt_service.get_user_token(@user)

        render json: {
          status: 'SUCCESS',
          message: "user was successfully logged in through #{params[:provider]}",
          data: {
            token: jwt_response,
            user_id: @user.slug
          }
        }, status: :created
      else
        render json: {
          status: 'FAILURE',
          message: "There was a problem signing you in through #{params[:provider]}",
          data: @user.errors
        }, status: :unprocessable_entity
      end
  end
end