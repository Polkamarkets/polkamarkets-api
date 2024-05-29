module Redeemable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_redeem_code, if: -> { redeem_code.blank? }

    def generate_redeem_code
      # random string with 6 downcase and uppercase letters
      redeem_code = SecureRandom.alphanumeric(6)

      # ensure uniqueness
      while User.exists?(redeem_code: redeem_code)
        redeem_code = SecureRandom.alphanumeric(6)
      end

      self.redeem_code = redeem_code
    end
  end
end
