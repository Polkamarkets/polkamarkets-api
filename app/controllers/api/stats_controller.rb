module Api
  class StatsController < BaseController
    def index
      if params[:from].blank? && params[:to].blank?
        # only fetching cached stats without params
        stats = Rails.cache.fetch("api:stats") do
          StatsService.new.get_stats
        end
      else
        stats = StatsService.new.get_stats(from: params[:from].to_i, to: params[:to].to_i)
      end

      render json: stats, status: :ok
    end

    def by_timeframe
      stats = StatsService.new.get_stats_by_timeframe(
        from: params[:from],
        to: params[:to],
        timeframe: params[:timeframe]
      )

      render json: stats, status: :ok
    end
  end
end
