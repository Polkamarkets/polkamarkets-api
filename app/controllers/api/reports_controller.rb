module Api
  class ReportsController < BaseController
    def create
      report = Report.new
      report.content = report_params[:content]
      report.reportable = reportable
      report.user = current_user
      report.save!

      render json: report, status: :created
    end

    private

    def reportable
      @_reportable ||=
        case report_params[:reportable_type]
        when 'Market', 'Question'
          Market.friendly.find(report_params[:reportable_id])
        when 'TournamentGroup', 'Land'
          TournamentGroup.friendly.find(report_params[:reportable_id])
        when 'Tournament', 'Contest'
          Tournament.friendly.find(report_params[:reportable_id])
        when 'Comment'
          Comment.find(report_params[:reportable_id])
        else
          raise ActiveRecord::RecordNotFound
        end
    end

    def report_params
      params.require(:report).permit(:content, :reportable_id, :reportable_type)
    end
  end
end
