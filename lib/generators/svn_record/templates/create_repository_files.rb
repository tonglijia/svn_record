class CreateRepositoryFiles < ActiveRecord::Migration

	def change
		  create_table :repository_files do |t|
			  t.column  :change_id,              :integer   # change_id :: 修订ID
			  t.column :action,                     :string     # action :: 状态 可为=> %w[A C D I M R X]
			  t.column :path,                         :string     # path :: 目录
			  t.column :from_path,               :string     # from_path :: 目录来源
			  t.column :from_revision,       :string     # from_revision :: 版本来源
			  t.column :revision,                 :string     # revision :: 版本号
			  t.column :branch,                     :string     # branch :: 分支
		  end
		  add_index :repository_files,  :change_id                             # index
	end
end






