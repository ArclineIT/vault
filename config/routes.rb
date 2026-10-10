Rails.application.routes.draw do
  root "home#show"

  namespace :v1, format: false do
    get    "envs", to: "environments#index"
    post   "envs", to: "environments#create"
    delete "envs/:env_name", to: "environments#destroy"

    scope "envs/:env_name" do
      get    "secrets",       to: "secrets#index"
      post   "secrets",       to: "secrets#create"
      get    "secrets/:name", to: "secrets#show",    constraints: { name: %r{[^/]+} }
      delete "secrets/:name", to: "secrets#destroy", constraints: { name: %r{[^/]+} }
      get    "export",        to: "secrets#export"
      post   "import",        to: "secrets#import"
    end

    get "audit", to: "audit#index"
  end

  # Health check for load balancers and uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check
end
