SvnRecord::Engine.routes.draw do
	namespace :repository do
		resources :changes, only: [:index] do
			collection do
			get :diff
				get :list
				get :entry
			end
			member do
				get :revisions
			end
		end
	end
end
Rails.application.routes.draw do
	mount SvnRecord::Engine => ""
end
