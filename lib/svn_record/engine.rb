require 'jquery-rails'
require 'slim'
require 'svn/mime_type'
require 'svn/scm/adapters/subversion'
require 'svn/helper'

module SvnRecord
	class Engine < ::Rails::Engine
		isolate_namespace SvnRecord
	end
end
