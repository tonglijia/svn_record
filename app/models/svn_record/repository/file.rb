##
# = 版本 文件 表
# 
# == Fields
# 
# change_id :: 修订ID
# action :: 状态 可为=> %w[A C D I M R X]
# path :: 目录
# from_path :: 目录来源
# from_revision :: 版本来源
# revision :: 版本号
# branch :: 分支
# 
# == Indexes
#

class SvnRecord::Repository::File < ActiveRecord::Base
	self.table_name = "repository_files"
	attr_accessible :change_id, :action, :path, :from_path, :from_revision, :revision, :branch, :change
end
