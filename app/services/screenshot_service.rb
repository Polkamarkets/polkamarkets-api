require 'puppeteer-ruby'

class ScreenshotService
  def capture(url)
    file_path = Rails.root.to_s + "/tmp/screenshot_#{SecureRandom.uuid}.png"

    Puppeteer.launch do |browser|
      page = browser.new_page
      page.viewport = Puppeteer::Viewport.new(width: 1200, height: 630)
      page.goto(url, wait_until: 'networkidle0')
      page.screenshot(path: file_path)
      file_path
    end
  end
end
