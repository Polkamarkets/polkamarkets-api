class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :market

  validates :body, presence: true, length: { maximum: 500 }

  has_many :replies, class_name: 'Comment', foreign_key: :parent_id, dependent: :destroy
  has_many :likes, as: :likeable, dependent: :destroy
  has_many :reports, as: :reportable, dependent: :destroy

  belongs_to :parent, class_name: 'Comment', optional: true

  scope :root_comments, -> { where(parent_id: nil) }

  # only allow one parent nested level
  validate :only_one_parent

  def only_one_parent
    return if parent_id.blank? || parent.parent_id.blank?

    errors.add(:parent_id, 'only one parent nested level allowed')
  end

  def replies_count
    replies.count
  end

  def timestamp
    created_at.to_i
  end
end
