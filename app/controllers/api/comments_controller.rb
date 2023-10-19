module Api
  class CommentsController < BaseController
    before_action :authenticate_user!, only: [:create]

    def create
      # market_slug must be converted to market_id
      market = Market.find_by(slug: comment_params[:market_slug])

      # create comment
      @comment = Comment.new(
        body: comment_params[:body],
        user_id: current_user.id,
        market_id: market.id,
        parent_id: comment_params[:parent_id]
      )

      if @comment.save
        render json: @comment, status: :ok
      else
        render json: @comment.errors, status: :unprocessable_entity
      end
    end

    private

    def comment_params
      params
        .require(:comment)
        .permit(
          :body,
          :market_slug,
          :parent_id,
        )
    end
  end
end
