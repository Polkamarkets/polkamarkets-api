module Immutable
  extend ActiveSupport::Concern

  included do
    validate :immutable_validation

    def immutable_validation
      # if market is already published on chain, then some fields can't be edited no more
      return if eth_market_id.blank? || eth_market_id_was.blank?

      self.class::IMMUTABLE_FIELDS.each do |field|
        errors.add(field, "You can't change this field after publishing on Ethereum!") if public_send("#{field}_changed?")
      end
    end
  end
end
