Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  root "home#index"
  get "rooms/join", to: "rooms#join_form", as: :join_room
  post "rooms/:code/join", to: "rooms#join", as: :join_room_with_code

  resources :rooms, only: %i[create show], param: :code

  get "up" => "rails/health#show", as: :rails_health_check
end
