Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'localhost:3000', '127.0.0.1:3000', 'localhost:80', '127.0.0.1:80', 'localhost:5000', '127.0.0.1:5000', '/[a-z0-9\-]+\.ngrok\.io/', 'app.polkamarkets.com', 'polkamarkets-staging.herokuapp.com', 'polkamarkets-web.herokuapp.com', 'polkamarkets-web-moonriver.herokuapp.com', 'testnet.polkamarkets.com', 'ifl.polkamarkets.com', 'polkamarkets-admin-ifl.herokuapp.com'
    resource '*', headers: :any, methods: %i(get post put patch delete options head)
  end
end
