class OgImageWorker
  include Sidekiq::Worker

  def perform(resource_type, resource_id)
    resource = resource_type.constantize.find_by(id: resource_id)
    return if resource.blank?

    resource.update_og_image
    resource.refresh_serializer_cache_sync! if resource.respond_to?(:refresh_serializer_cache_sync!)
  end
end
