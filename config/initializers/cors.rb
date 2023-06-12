Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # origins coming from env comma separated
    origins *ENV['CORS_ORIGINS'].to_s.split(',')
    resource '*', headers: :any, methods: %i(get post put patch delete options head)
  end
end
