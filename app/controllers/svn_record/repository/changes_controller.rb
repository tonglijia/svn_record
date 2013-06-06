class SvnRecord::Repository::ChangesController < SvnRecord::Repository::ApplicationController
	layout 'svn_record/subversion'
	before_filter :find_repository_params
	def index
		SvnRecord::Repository::Change.scm.fetch_changesets unless @path.present?
		@entries = SvnRecord::Repository::Change.scm.entries(@path) 
		@changesets = SvnRecord::Repository::Change.fetch_revisions(@entries).limit(10)
	rescue
		render text: '请检查SVN配置以及安装过程是否有问题'
	end
 
	def list
		@entries = SvnRecord::Repository::Change.scm.entries(@path) 
		@changesets = SvnRecord::Repository::Change.fetch_revisions(@entries)
	end
	
	def entry
		@content = SvnRecord::Repository::Change.scm.cat(@path, params[:rev])
		@changesets  = SvnRecord::Repository::Change.revisions(@path)
	end
	
	def revisions	
		@changeset = SvnRecord::Repository::Change.find_by_revision(params[:id])
	end

	def diff
		@diff = SvnRecord::Repository::Change.scm.diff(@path, params[:rev], params[:rev_to])
	end
  
	protected

	def find_repository_params
		@root_name = SvnRecord::Repository::Change.scm.root_name
		@path = params[:path].to_s
	end


end
