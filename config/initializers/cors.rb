Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'localhost:3000', '127.0.0.1:3000', 'app.polkamarkets.com', 'polkamarkets-staging.herokuapp.com', 'polkamarkets-web.herokuapp.com', 'polkamarkets-web-moonriver.herokuapp.com', 'testnet.polkamarkets.com'
    resource '*', headers: :any, methods: %i(get post put patch delete options head)
  end
end
