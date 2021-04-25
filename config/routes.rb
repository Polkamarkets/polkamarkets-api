Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  namespace :admin do
    root :to => "markets#index"

    resources :markets do
      member do
        post :publish
        post :resolve
      end
    end
  end

  scope :module => 'api' do
    resources :markets, only: [:index, :show] do
      member do
        post :reload
      end
    end

    resources :portfolios, only: [:show] do
      member do
        post :reload
      end
    end
  end

  root to: 'api/ping#ping'
end
