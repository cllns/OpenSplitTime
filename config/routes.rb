Rails.application.routes.draw do
  root to: 'visitors#index'
  get 'about', to: 'visitors#about'
  get 'donations', to: 'visitors#donations'
  get 'getting_started', to: 'visitors#getting_started'
  get 'getting_started_2', to: 'visitors#getting_started_2'
  get 'getting_started_3', to: 'visitors#getting_started_3'
  get 'getting_started_4', to: 'visitors#getting_started_4'
  get 'getting_started_5', to: 'visitors#getting_started_5'
  get 'course_info', to: 'visitors#course_info'
  get 'effort_info', to: 'visitors#effort_info'
  get 'event_info', to: 'visitors#event_info'
  get 'location_info', to: 'visitors#location_info'
  get 'participant_info', to: 'visitors#participant_info'
  get 'race_info', to: 'visitors#race_info'
  get 'split_info', to: 'visitors#split_info'
  get 'split_time_info', to: 'visitors#split_time_info'
  devise_for :users, :controllers => {registrations: 'registrations'}
  resources :users do
    member { get :participants }
    member { put :associate_participant }
    member { post :add_interest }
    collection { get :my_interests }
    member { get :edit_preferences }
    member { put :update_preferences }
  end
  resources :locations
  resources :courses do
    member { get :best_efforts }
    member { get :plan_effort }
  end
  resources :events do
    member { post :import_splits }
    member { post :import_efforts }
    member { get :splits }
    member { put :associate_split }
    member { put :associate_splits }
    member { delete :remove_split }
    member { delete :remove_all_splits }
    member { get :reconcile }
    member { get :stage}
  end
  resources :splits do
    member { get :assign_location }
    collection { get :best_efforts }
  end
  resources :races
  resources :participants do
    collection { get :subregion_options }
    member { get :avatar_claim }
    member { delete :avatar_disclaim }
    collection { post :create_from_efforts }
    collection { get :search }
    member { get :merge }
    member { put :combine }
    member { delete :remove_effort }
  end
  resources :efforts do
    member { put :associate_participant }
    collection { put :associate_participants}
    member { put :edit_split_times }
    member { delete :delete_waypoint_group }
  end
  resources :split_times
  resources :interests
  get '/auth/:provider/callback' => 'sessions#create'
  get '/signin' => 'sessions#new', :as => :signin
  get '/signout' => 'sessions#destroy', :as => :signout
  get '/auth/failure' => 'sessions#failure'

  namespace :admin do
    root 'dashboard#dashboard'
    get 'flag_split_times', to: 'dashboard#flag_split_times'
  end
end
