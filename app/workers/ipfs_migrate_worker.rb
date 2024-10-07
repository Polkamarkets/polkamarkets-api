class IpfsMigrateWorker
  include Sidekiq::Worker

  def perform(model_name, model_id, field_name)
    model = model_name.constantize.find(model_id)
    model.migrate_ipfs_image_to_cloudflare(field_name)
  end
end
