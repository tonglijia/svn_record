module ActionView
	module Helpers
		module DateHelper
			def distance_of_date_in_words(from_date, to_date = 0, options = {})
				from_date = from_date.to_date if from_date.respond_to?(:to_date)
				to_date = to_date.to_date if to_date.respond_to?(:to_date)
				distance_in_days = (to_date - from_date).abs
				
				I18n.with_options :locale => options[:locale], :scope => :'datetime.distance_in_words' do |locale|
					case distance_in_days
					when 0..60     then locale.t :x_days,             :count => distance_in_days.round
					when 61..720   then locale.t :about_x_months,     :count => (distance_in_days / 30).round
					else locale.t :over_x_years, :count => (distance_in_days / 365).floor
					end
				end
			end
			
			def to_path_param(path)
				str = path.to_s.split(%r{[/\\]}).select{|p| p.present?} #.join("/")
				str.shift if str.length > 1
				str = str.compact.join("/")
				str.blank? ? nil : str
			end
			
			def render_changeset_changes
				changes = @changeset.files.limit(1000).reorder('path').all.collect do |change|
					case change.action
					when 'A'
						# Detects moved/copied files
						if !change.from_path.blank?
							change.action =
							@changeset.files.detect {|c| c.action == 'D' && c.path == change.from_path} ? 'R' : 'C'
						end
						change
					when 'D'
						@changeset.files.detect {|c| c.from_path == change.path} ? nil : change
					else
						change
					end
				end.compact
				
				tree = {}
				changes.each do |change|
					p = tree
					dirs = change.path.to_s.split('/').select {|d| !d.blank?}
					path = ''
					dirs.each do |dir|
						path += '/' + dir
						p[:s] ||= {}
						p = p[:s]
						p[path] ||= {}
						p = p[path]
					end
					p[:c] = change
				end
				render_changes_tree(tree[:s])
			end
			
			def render_changes_tree(tree)
				return '' if tree.nil?
				output = ''
				output << '<ul>'
				tree.keys.sort.each do |file|
					style = 'change'
					text = File.basename(h(file))
					if s = tree[file][:s]
						style << ' folder'
						path_param = to_path_param(file)
						text = link_to(h(text), repository_changes_path(path: path_param))
						output << "<li class='#{style}'>#{text}"
						output << render_changes_tree(s)
						output << "</li>"
					elsif c = tree[file][:c]
						style << " change-#{c.action}"
						path_param = to_path_param(c.path)
						text = link_to(h(text), entry_repository_changes_path(path: path_param)) unless c.action == 'D'
						text << " - #{h(c.revision)}" unless c.revision.blank?
						text << ' '.html_safe + content_tag('span', h(c.from_path), :class => 'copied-from') unless c.from_path.blank?
						output << "<li class='#{style}'>#{text}</li>"
					end
				end
				output << '</ul>'
				output.html_safe
			end
			
			def syntax_highlight_lines(name, content)
				lines = []
				syntax_highlight(name, content).each_line { |line| lines << line }
				lines
			end
			
			def syntax_highlight(name, content)
				Svn::SyntaxHighlighting.highlight_by_filename(content, name)
			end
			
			def menu_node(path,array = [])
				link_root = link_to @root_name, repository_changes_path
				return raw(link_root) unless path.present?
				paths = path.split('/').map do |p|
					array << p 
					p == path.split('/').last ? p : link_to(p, repository_changes_path(path: array.join('/')))
				end
				paths.unshift(link_root)
				raw paths.join("/")
			end
		end
	end
end