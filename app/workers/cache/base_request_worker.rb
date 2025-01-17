class Cache::BaseRequestWorker
  include Sidekiq::Worker

  def perform(resource_type, resource_id)
    resource = resource_type.constantize.find_by(id: resource_id)
    return if resource.blank?

    BaseRequestCacheService.new(resource).refresh_markets
  end
end
