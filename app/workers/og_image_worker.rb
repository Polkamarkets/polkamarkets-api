class OgImageWorker
  include Sidekiq::Worker

  def perform(resource_type, resource_id)
    resource = resource_type.constantize.find_by(id: resource_id)
    return if resource.blank?

    resource.update_og_image
  end
end
