class OgImageWorker
  include Sidekiq::Worker

  def perform(resource_type, resource_id)
    resource = resource_type.constantize.find(resource_id)
    screenshot = ScreenshotService.new.capture(resource.og_image_url)
    resource.upload_og_image(screenshot)
  end
end
