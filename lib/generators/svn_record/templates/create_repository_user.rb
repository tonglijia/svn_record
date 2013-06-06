class CreateRepositoryUser < ActiveRecord::Migration
	
	def change
		create_table :repository_users do |t|
			t.column  :name,              :string
		end 
	end
end
