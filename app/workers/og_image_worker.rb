class OgImageWorker
  include Sidekiq::Worker

  def perform(resource_type, resource_id)
    resource = resource_type.constantize.find(resource_id)

    screenshot_path = ScreenshotService.new.capture(resource.og_image_url_before_upload)

    resource.upload_og_image(screenshot_path)
  end
end
