module OgImageable
  extend ActiveSupport::Concern

  OG_IMAGEABLE_FIELDS = %w[].freeze

  included do
    after_create :update_og_image_async
    after_update :update_og_image_async, if: -> { og_imageable_fields_changed? }

    def og_imageable_fields_changed?
      self.class::OG_IMAGEABLE_FIELDS.any? { |field| saved_change_to_attribute?(field) }
    end

    def update_og_image_async
      OgImageWorker.perform_async(self.class.name, id)
    end

    def update_og_image
      begin
        file_path = ScreenshotService.new.capture(og_image_web_url)

        file = File.open(file_path)

        cloudflare_service = CloudflareService.new
        response = cloudflare_service.add_image(file)

        variant = response['result']['variants'].find { |v| v.include?('public') }
        raise "No public variant found for OG image" if variant.blank?

        current_og_image_url = og_image_url

        self.og_image_url = variant
        self.save!

        # delete previous image for storage optimization
        cloudflare_service.delete_image_from_url(current_og_image_url) if current_og_image_url.present?
      ensure
        File.delete(file_path) if File.exist?(file_path)
      end
    end

    def og_image_web_url
      url = "#{Rails.application.config_for(:polkamarkets).web_url}/og/#{self.class::OG_IMAGEABLE_PATH}/#{slug}"
      url += "?theme=#{og_theme}" if respond_to?(:og_theme) && og_theme.present?
      url
    end
  end
end
