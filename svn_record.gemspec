$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "svn_record/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name = "svn_record"
  s.version = SvnRecord::VERSION
  s.authors = ["Lijia Tong"]
  s.email = ["wtuyuupe@163.com"]
  s.homepage = "https://github.com/tonglijia/svn_record"
  s.summary = "svn version control program"
  s.description = "Used to manage them in the svn project"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["Rakefile", "README.md"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", ">= 3.2.13"
  s.add_dependency "jquery-rails"
  s.add_dependency 'jquery-ui-rails'
  s.add_dependency 'slim'
  s.add_dependency 'coderay'


end