module Cloudflareable
  extend ActiveSupport::Concern

  included do
    def update_image_to_cloudflare(image_field)
      return if self[image_field].nil?

      cloudflare_service = CloudflareService.new
      response = cloudflare_service.add_image_from_url(self[image_field])

      # finding public variant
      variant = response['result']['variants'].find { |v| v.include?('public') }
      raise "No public variant found for #{self[image_field]}" if variant.blank?

      self[image_field] = variant
      self.save!
    end
  end
end
