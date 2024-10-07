module Imageable
  extend ActiveSupport::Concern

  IMAGEABLE_FIELDS = %w[].freeze

  included do
    before_save :imageable_migration

    def ipfs_hash_from_url(url)
      url.split('/').last
    end

    def is_ipfs_hash?(url)
      # fetching last part of url
      hash = ipfs_hash_from_url(url)

      hash.length == 46 && hash.start_with?('Qm')
    end

    def migrate_ipfs_image_to_cloudflare(image_field)
      image_url = self[image_field]

      return if image_url.blank?
      return unless is_ipfs_hash?(image_url)

      # checking if hash is already mapped
      ipfs_mapping = IpfsMapping.find_by(ipfs_hash: ipfs_hash_from_url(image_url))

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
      IpfsMapping.create!(ipfs_hash: ipfs_hash_from_url(image_url), url: variant)

      self[image_field] = variant
      self.save!

      self[image_field]
    end

    def imageable_migration
      self.class::IMAGEABLE_FIELDS.each do |field|
        puts field
        next if self[field].blank? || !is_ipfs_hash?(self[field])

        IpfsMigrateWorker.perform_async(self.class.name, id, field)
      end
    end
  end
end
