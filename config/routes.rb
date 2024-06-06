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

    resources :tournaments, only: [:create, :update, :destroy] do
      member do
        post :move_up
        post :move_down
      end
    end
    resources :tournament_groups, only: [:create, :update, :destroy] do
      member do
        post :move_up
        post :move_down
      end
    end
  end

  scope :module => 'api' do
    resources :markets, only: [:index, :show, :create] do
      member do
        post :reload
        get :feed
      end
    end

    resources :portfolios, only: [:show], constraints: { id: /.*/ } do
      member do
        post :reload
        get :feed
      end
    end

    put 'users' => 'users#update'
    delete 'users' => 'users#destroy'
    post 'users/register' => 'users#register_waitlist'
    post 'users/redeem' => 'users#redeem_code'

    resources :articles, only: [:index]
    resources :whitelist, only: [:index]
    resources :achievements, only: [:index, :show]
    get 'leaderboard' => 'leaderboards#index' # legacy route
    resources :leaderboards, only: [:index, :show], constraints: { id: /.*/ } do
      collection do
        get 'winners', to: 'leaderboards#winners'
      end
    end

    resources :group_leaderboards, only: [:index, :show, :create, :update] do
      member do
        post :join
      end
    end

    resources :tournaments, only: [:index, :show, :create, :update, :destroy] do
      member do
        post :move_up
        post :move_down
        get :markets, to: 'tournaments#show_markets'
      end
    end
    # TODO remove; legacy
    resources :tournament_groups, only: [:index, :show]

    resources :lands, controller: :tournament_groups, only: [:index, :show, :create, :update, :destroy] do
      member do
        post :move_up
        post :move_down
        get :markets, to: 'tournament_groups#show_markets'
      end
    end

    resources :reports, only: [:create]
    resources :likes, only: [:create] do
      collection do
        delete '/', to: 'likes#destroy'
      end
    end

    get 'achievement_tokens/:network/:id', to: 'achievement_tokens#show'

    resources :stats, only: [:index] do
      collection do
        get ':timeframe', to: 'stats#by_timeframe'
      end
    end

    # only allowing comment creation for now
    resources :comments, only: [:create]

    resources :user_operations, only: [:index, :show, :create]

    if !Rails.env.production?
      post 'webhooks/faucet' => "webhooks#faucet"
    end

    # workaround due to js-ipfs library CORS error: https://community.infura.io/t/ipfs-cors-error/3149/
    post 'ipfs/add' => "ipfs#add"
  end

  root to: 'api/ping#ping'
end
