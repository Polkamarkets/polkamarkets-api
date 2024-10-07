module Imageable
  extend ActiveSupport::Concern

  IMAGEABLE_FIELDS = %w[].freeze

  included do
    after_save :imageable_migration

    def migrate_ipfs_image_to_cloudflare(image_field)
      image_url = self[image_field]

      return if image_url.blank?
      return unless IpfsService.is_ipfs_hash?(image_url)

      # checking if hash is already mapped
      ipfs_mapping = IpfsMapping.find_by(ipfs_hash: IpfsService.ipfs_hash_from_url(image_url))

      if ipfs_mapping.present?
        self[image_field] = ipfs_mapping.url
        self.save!

        return self[image_field]
      end

      cloudflare_service = CloudflareService.new
      response = cloudflare_service.add_image_from_url(image_url)

      # finding public variant
      variant = response['result']['variants'].find { |v| v.include?('public') }
      raise "No public variant found for #{image_url}" if variant.blank?

      # saving mapping
      IpfsMapping.create!(ipfs_hash: IpfsService.ipfs_hash_from_url(image_url), url: variant)

      self[image_field] = variant
      self.save!

      self[image_field]
    end

    def imageable_migration
      self.class::IMAGEABLE_FIELDS.each do |field|
        # field still not persisted
        next unless self.persisted?

        next if self[field].blank? || !IpfsService.is_ipfs_hash?(self[field])

        IpfsMigrateWorker.perform_async(self.class.name, id, field)
      end
    end
  end
end
