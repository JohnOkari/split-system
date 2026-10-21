Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :webhooks do
    namespace :mpesa do
      post "c2b/:callback_token/confirmation", to: "payments#confirmation"
      post "b2c/:callback_token/result", to: "payouts#result"
      post "b2c/:callback_token/timeout", to: "payouts#timeout"
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
