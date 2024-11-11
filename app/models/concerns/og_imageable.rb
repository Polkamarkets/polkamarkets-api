module OgImageable
  extend ActiveSupport::Concern

  included do
    after_create :generate_og_image

    def generate_og_image
      OgImageWorker.perform_async(self.class.name, id)
    end

    def upload_og_image(file)
      cloudflare_service = CloudflareService.new
      response = cloudflare_service.add_image(file)

      variant = response['result']['variants'].find { |v| v.include?('public') }
      raise "No public variant found for OG image" if variant.blank?

      update(og_image_url: variant)
    end

    def og_image_url
      "#{ENV['OG_IMAGES_URL']}/og/#{self.class::OG_IMAGEABLE_PATH}/#{slug}"
    end
  end
end
