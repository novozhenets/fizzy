Rails.application.routes.draw do
  root "splats#index"

  resource :session

  resources :splats do
    resources :categories, shallow: true
  end

  resources :categories, only: :index

  get "up", to: "rails/health#show", as: :rails_health_check
end
