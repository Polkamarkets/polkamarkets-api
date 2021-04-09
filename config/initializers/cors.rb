Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'localhost:4000', '127.0.0.1:4000', '*.polkamarkets.com', 'polkamarkets-staging.herokuapp.com'
    resource '*', headers: :any, methods: %i(get post put patch delete options head)
  end
end
