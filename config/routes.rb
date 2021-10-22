require 'sidekiq/web'

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  namespace :admin do
    root :to => "markets#index"

    Sidekiq::Web.use Rack::Auth::Basic do |username, password|
      # Protect against timing attacks:
      # - See https://codahale.com/a-lesson-in-timing-attacks/
      # - See https://thisdata.com/blog/timing-attacks-against-string-comparison/
      # - Use & (do not use &&) so that it doesn't short circuit.
      # - Use digests to stop length information leaking (see also ActiveSupport::SecurityUtils.variable_size_secure_compare)
      ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username), ::Digest::SHA256.hexdigest(ENV["ADMIN_USERNAME"])) &
        ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(ENV["ADMIN_PASSWORD"]))
    end if !Rails.env.development?
    mount Sidekiq::Web, at: "/sidekiq"

    resources :markets do
      member do
        post :publish
        post :resolve
      end
    end

    get 'stats' => "stats#index"
    get 'leaderboard' => "stats#leaderboard"
  end

  scope :module => 'api' do
    resources :markets, only: [:index, :show, :create] do
      member do
        post :reload
      end
    end

    resources :portfolios, only: [:show] do
      member do
        post :reload
      end
    end

    resources :whitelist, only: [:show]

    post 'webhooks/faucet' => "webhooks#faucet"

    # workaround due to js-ipfs library CORS error: https://community.infura.io/t/ipfs-cors-error/3149/
    post 'ipfs/add' => "ipfs#add"
  end

  root to: 'api/ping#ping'
end
