module Api
  class StatsController < BaseController
    def index
      if params[:from].blank? && params[:to].blank?
        # only fetching cached stats without params
        stats = Rails.cache.fetch("api:stats", expires_in: 24.hours) do
          StatsService.new.get_stats
        end
      else
        stats = StatsService.new.get_stats(from: params[:from].to_i, to: params[:to].to_i)
      end

      render json: stats, status: :ok
    end
  end
end
