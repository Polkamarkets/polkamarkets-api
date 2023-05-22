require 'sidekiq/web'

Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  namespace :admin do
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
        get :feed
      end
    end

    put 'users' => 'users#update'

    resources :articles, only: [:index]
    resources :whitelist, only: [:show]
    resources :achievements, only: [:index, :show]
    get 'leaderboard' => 'leaderboards#index' # legacy route
    resources :leaderboards, only: [:index, :show] do
      collection do
        get 'winners', to: 'leaderboards#winners'
      end
    end

    resources :group_leaderboards, only: [:index, :show, :create, :update] do
      member do
        post :join
      end
    end

    resources :tournaments, only: [:index, :show]

    get 'achievement_tokens/:network/:id', to: 'achievement_tokens#show'

    resources :stats, only: [:index] do
      collection do
        get ':timeframe', to: 'stats#by_timeframe'
      end
    end

    if !Rails.env.production?
      post 'webhooks/faucet' => "webhooks#faucet"
    end

    # workaround due to js-ipfs library CORS error: https://community.infura.io/t/ipfs-cors-error/3149/
    post 'ipfs/add' => "ipfs#add"
  end

  root to: 'api/ping#ping'
end
