require 'puppeteer-ruby'

class ScreenshotService
  def capture(url)
    Puppeteer.launch do |browser|
      puts 'Puppeteer launched'
      page = browser.new_page
      page.viewport = Puppeteer::Viewport.new(width: 1200, height: 630)
      page.goto(url)
      file_path = Rails.root.to_s + "/tmp/screenshot_#{SecureRandom.uuid}.png"
      page.screenshot(path: file_path)
      File.open(file_path)
    # ensure
    #   File.delete(file_path) if File.exist?(file_path)
    end
  end
end
