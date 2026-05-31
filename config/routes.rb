Rails.application.routes.draw do
  root "dashboard#show"
  resource :session, only: %i[new create destroy]
  get "/dashboard", to: "dashboard#show"

  namespace :backoffice do
    resources :service_invoices, only: %i[index show] do
      post :issue, on: :member
      post :cancel, on: :member
      post :poll_status, on: :member
    end
    resources :customers, only: :index
    resources :fiscal_profiles, only: :index
    resources :memberships, only: :index
  end

  get "/up", to: "platform#live"
  get "/ready", to: "platform#ready"
  get "/metrics", to: "platform#metrics"

  namespace :v1 do
    resources :organizations, only: :create
    get "/organization", to: "organizations#show"
    resources :memberships, only: %i[index create update] do
      patch :rotate_token, on: :member
      patch :revoke_token, on: :member
    end
    resources :fiscal_profiles, only: %i[index create show update]
    resources :customers, only: %i[index create show update]
    resources :service_invoices, only: %i[index create show] do
      post :issue, on: :member
      post :cancel, on: :member
      post :poll_status, on: :member
    end
    post "/provider_callbacks/nfse", to: "provider_callbacks#nfse"
  end
end
