class Cache::BaseRequestWorker
  include Sidekiq::Worker

  def perform(resource_type, resource_id)
    resource = resource_type.constantize.find_by(id: resource_id)
    return if resource.blank?

    states = [nil, 'open', 'closed', 'resolved']
    brc_service = BaseRequestCacheService.new(resource)

    states.each do |state|
      brc_service.refresh_markets(state: state)
    end
  end
end
