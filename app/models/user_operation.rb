class UserOperation < ApplicationRecord
  validates_presence_of :network_id, :user_address, :user_operation_hash, :user_operation, :user_operation_data

  before_validation :fill_user_address_from_user_operation

  enum status: {
    pending: 0,
    success: 1,
    failed: 2
  }

  def fill_user_address_from_user_operation
    self.user_address ||= user_operation['sender'] if user_operation.present?
  end
end
