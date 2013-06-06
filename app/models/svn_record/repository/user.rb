##
# = 版本 修订 表
# 
# == Fields
# 
# id :: 用户ID
# 
# == Indexes
#
	class SvnRecord::Repository::User < ActiveRecord::Base
		self.table_name = 'repository_users'
		attr_accessible   :name
		has_many :changes
	end
