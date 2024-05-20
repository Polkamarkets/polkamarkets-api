class Report < ApplicationRecord
  belongs_to :user
  belongs_to :reportable, polymorphic: true

  validates_presence_of :content

  after_create :notify!

  ALLOWED_REPORTABLE_TYPES = %w[Market TournamentGroup Tournament Comment].freeze
  # temporary while types are not migrated
  REPORTABLE_MAPPINGS = {
    'Market' => 'Question',
    'TournamentGroup' => 'ContestGroup',
    'Tournament' => 'Contest',
    'Comment' => 'Comment'
  }.freeze

  validates :reportable_type, inclusion: { in: ALLOWED_REPORTABLE_TYPES }

  def reportable_type_item
    REPORTABLE_MAPPINGS[reportable_type]
  end

  def email_template
    "<!DOCTYPE html>
    <html>
      <body>
        <h1>#{reportable_type_item} Report</h1>
        <p>User #{user&.email} reported #{reportable_type_item} \"#{reportable_title}\"</p>
        <p>Report Type: \"#{content}\"</p>
        <p>#{reportable&.public_url}</p>
      </body>
    </html>"
  end

  def email_subject
    "New Item Reported"
  end

  def reportable_public_url
    reportable.public_url
  end

  def reportable_title
    reportable.content_title
  end

  def notify!
    return if reported?

    NotifyReportWorker.perform_async(id)
  end
end
