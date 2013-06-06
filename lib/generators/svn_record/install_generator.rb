module SvnRecord
	class InstallGenerator < Rails::Generators::Base
		include Rails::Generators::Migration
		source_root File.expand_path('../templates', __FILE__)
		argument :langs, type: :array, :default => ['en']
		def self.next_migration_number(path)
			@migration_number = Time.now.utc.strftime("%Y%m%d%H%M%S%6N").to_i.to_s
		end
		def install_translation
			migration_template '../templates/create_repository_changes.rb', 'db/migrate/create_repository_changes.rb'
			migration_template '../templates/create_repository_files.rb', 'db/migrate/create_repository_files.rb'
			migration_template '../templates/create_repository_user.rb', 'db/migrate/create_repository_user.rb'
			copy_file '../../../../config/configuration.yml', 'config/configuration.yml'
		end
	end
end