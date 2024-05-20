class NotifyReportWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3

  def perform(report_id)
    report = Report.find_by(id: report_id)
    return if report.blank? || report.reported?

    BrevoService.new.send_raw_email(
      email: Rails.application.config_for(:brevo).admin_email,
      subject: report.email_subject,
      html_content: report.email_template
    )

    report.update(reported: true)
  end
end
