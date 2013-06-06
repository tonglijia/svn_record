##
# = 版本 修订 表
# 
# == Fields
# 
# user_id :: 用户ID
# revision :: 版本号
# committer :: 提交人
# comment :: 注释
# committed_at :: 提交时间
	# 
# == Indexessu 
#

class SvnRecord::Repository::Change < ActiveRecord::Base
	self.table_name = 'repository_changes'
	include Svn::Scm::Adapters
	attr_accessible  :revision, :committer, :comment, :committed_at, :user_id
	has_many :files
	belongs_to :user
	scope :committed_desc, order('revision DESC')

	def self.scm
		Subversion.new
	end

	def self.fetch_revisions(entries)
		where("revision <= ?", entries.map(&:lastrev).map{|lastrev| lastrev.identifier.to_i}.max).order("id DESC")
	end

	def self.revisions(path)
		where(revision: scm.revisions(path).map(&:identifier)).reorder('id')
	end

	def create_change(options, branch = "")
		SvnRecord::Repository::File.create(options.update(change_id: self.id,revision: self.revision, branch: branch))
	end
end

