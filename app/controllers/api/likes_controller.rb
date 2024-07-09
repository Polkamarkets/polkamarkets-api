module Api
  class LikesController < BaseController
    before_action :authenticate_user!, only: %i[create destroy]

    def create
      like = Like.new
      like.user = current_user
      like.likeable = likeable
      like.save!

      # destroying likeable cache
      likeable.touch

      render json: like
    end

    def destroy
      like = Like.find_by!(likeable: likeable, user: current_user)
      like.destroy!

      # destroying likeable cache
      likeable.touch

      render json: like
    end

    private

    def likeable
      @_likeable ||=
        case like_params[:likeable_type]
        when 'Market', 'Question'
          Market.friendly.find(like_params[:likeable_id])
        when 'Comment'
          Comment.find(like_params[:likeable_id])
        else
          raise ActiveRecord::RecordNotFound
        end
    end

    def like_params
      params.require(:like).permit(:likeable_id, :likeable_type)
    end
  end
end
