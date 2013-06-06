class CreateRepositoryChanges < ActiveRecord::Migration

	def change
	  create_table :repository_changes do |t|
		  t.column :user_id,                  :integer  # user_id :: 用户ID
		  t.column :revision,                 :integer     # revision :: 版本号
		  t.column :committer,              :string     # committer :: 提交人
		  t.column :comment,                  :string     # comment :: 注释
		  t.column :committed_at,        :string     # committed_at :: 提交时间
	  end
	  add_index :repository_changes,  :user_id
	end
end




