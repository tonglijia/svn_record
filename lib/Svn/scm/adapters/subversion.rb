require 'uri'
module Svn
  module Scm
    module Adapters
      class CommandFailed < StandardError; end
      class Subversion <  Struct.new(:url, :login, :password, :root_name, :root_url)
        class ScmCommandAborted < CommandFailed; end

        def initialize
          options = YAML.load(File.open("#{Rails.root}/config/configuration.yml")).values.first
          self.url = options['url']
          self.login = options['login']
          self.password = options['password']
          self.root_url = options['root_url']
          self.root_name = url.gsub(Regexp.new(root_url),'')
        end

        # shellout
        def shellout(cmd, options = {}, &block)
          Rails.logger.debug("Shelling out: #{strip_credential(cmd)}" )
          IO.popen(cmd, "r+") do |io|
            io.set_encoding("ASCII-8BIT") if io.respond_to?(:set_encoding)
            io.close_write unless options[:write_stdin]
            if options[:mark]
              block.call(io) if block_given?
            else
              output = io.read
              output.force_encoding('UTF-8') if output.respond_to?(:force_encoding)
              doc = parse_xml(output)
              block.call(doc,output) if block_given?
            end
          end
        rescue
        end

        def info
          info = nil
          cmd = "svn info --xml #{target}"
          cmd << credentials_string
          shellout(cmd){ |doc,_| info = Info.get_instance(doc) }
          info
        end

        def entries(path='', identifier=nil, options={})
          identifier = identifier.to_i > 0 ? identifier.to_i : "HEAD"
          entries = Entries.new
          cmd = " svn list --xml #{target(path)}@#{identifier}  #{credentials_string}" 
          shellout(cmd) do |doc,_|
            begin 
              changes = SvnRecord::Repository::Change.all.dup
              each_xml_element(doc['lists']['list'], 'entry') do |entry|
                commit = entry['commit']
                commit_date = commit['date']
                next if entry['kind'] == 'dir' && commit_date.nil?
                name = entry['name']['__content__']
                entries << Entry.new({:name => URI.unescape(name),
                  :path => ((path.empty? ? "" : "#{path}/") + name),
                  :kind => entry['kind'],
                  :size => ((s = entry['size']) ? s['__content__'].to_i : nil),
                  :lastrev => Revision.new({
                    :identifier => commit['revision'],
                    :time => Time.parse(commit_date['__content__'].to_s).localtime,
                    :author => ((a = commit['author']) ? a['__content__'] : nil),
                    :message => (change = changes.detect{|a| a.revision == commit['revision'].to_i}) ? change.comment : ""
                    })
                    })
                  end
            rescue Exception => e
              Rails.logger.error("Error parsing svn output: #{e.message}")
            end
          end
          return nil if $? && $?.exitstatus != 0
          entries.sort_by_name
        end

        def revisions(path='', identifier_from=nil, identifier_to=nil, options={})
          identifier_from = (identifier_from && identifier_from.to_i > 0) ? identifier_from.to_i : "HEAD"
          identifier_to = (identifier_to && identifier_to.to_i > 0) ? identifier_to.to_i : 1
          revisions = Revisions.new
          cmd = "svn log --xml -r #{identifier_from}:#{identifier_to}"
          cmd << credentials_string
          cmd << " --verbose " if  options[:with_paths]
          cmd << " --limit #{options[:limit].to_i}" if options[:limit]
          cmd << ' ' + target(path)
          shellout(cmd) do |doc,_|
            begin 
              each_xml_element(doc['log'], 'logentry') do |logentry|
                paths = []
                each_xml_element(logentry['paths'], 'path') do |path|
                  paths << { :action => path['action'],
                    :path => path['__content__'],
                    :from_path => path['copyfrom-path'],
                    :from_revision => path['copyfrom-rev']
                  }
                end if logentry['paths'] && logentry['paths']['path']
                paths.sort! { |x,y| x[:path] <=> y[:path] }
                revisions << Revision.new({:identifier => logentry['revision'],
                  :author => (logentry['author'] ? logentry['author']['__content__'] : ""),
                  :time => Time.parse(logentry['date']['__content__'].to_s).localtime,
                  :message => logentry['msg']['__content__'],
                  :paths => paths
                  })
                end
              rescue
              end
            end
            return nil if $? && $?.exitstatus != 0
            revisions
          end

          def diff(path, identifier_from, identifier_to=nil)
            path ||= ''
            identifier_from = (identifier_from and identifier_from.to_i > 0) ? identifier_from.to_i : ''
            identifier_to = (identifier_to and identifier_to.to_i > 0) ? identifier_to.to_i : (identifier_from.to_i - 1)
            cmd = "svn diff -r "
            cmd << "#{identifier_to}:"
            cmd << "#{identifier_from}"
            cmd << " #{target(path)}@#{identifier_from} #{credentials_string}" 
            diff = []
            shellout(cmd, {mark: true}) {|io|  io.each_line { |line| diff << line } }
            return nil if $? && $?.exitstatus != 0
            diff
          rescue
            nil
          end

          def cat(path, identifier=nil, cat=nil)
            identifier = (identifier and identifier.to_i > 0) ? identifier.to_i : "HEAD"
            path = path.gsub(Regexp.new("#{root_name}/"),'')
            cmd = "svn cat #{target(path)}@#{identifier} #{credentials_string}"
            shellout(cmd, {mark: true}) {|io|  io.binmode;  cat = io.read }
            return nil if $? && $?.exitstatus != 0
            cat
          end


          def latest_changesets(path, rev, limit=10)
            revisions = self.class.scm.revisions(path, rev, nil, :limit => limit).map(&:identifier).compact
            evisions.present? ? SvnRecord::Repository::Change.where(revision: revisions).order('revision DESC').all : []
          end

          def fetch_changesets
            if (scm_info = self.class.new.info)
              change = SvnRecord::Repository::Change.last
              db_revision =  change.present?  ?  change.revision.to_i : 0
              scm_revision = scm_info.lastrev.identifier.to_i
              branch = scm_info.lastrev.branch.present? ?  scm_info.lastrev.branch : "master"
              if db_revision < scm_revision
                # debug("Fetching changesets for repository #{url}" )
                identifier_from = db_revision + 1
                while (identifier_from <= scm_revision)
                  identifier_to = [identifier_from + 199, scm_revision].min
                  revisions('', identifier_to, identifier_from, :with_paths => true).reverse_each do |revision|
                    ActiveRecord::Base.transaction do
                      user = SvnRecord::Repository::User.find_by_name(revision.author.to_s.strip)
                      user = SvnRecord::Repository::User.create(name: revision.author.to_s.strip) if user.blank? && revision.author.to_s.strip.present?
                      changeset = SvnRecord::Repository::Change.create(user_id: user.id, revision:revision.identifier, committer:revision.author, committed_at: revision.time, comment: revision.message)
                      revision.paths.each { |change| changeset.create_change(change,branch)} unless changeset.new_record?
                    end
                  end if revisions.present?
                  identifier_from = identifier_to + 1
                end
              end
            end
          end
          
          def self.load_entries_changesets(entries)
            return unless entries.present?
            entries_with_identifier = entries.select {|entry| entry.lastrev && entry.lastrev.identifier.present?}
            identifiers = entries_with_identifier.map {|entry| entry.lastrev.identifier}.compact.uniq
            if identifiers.any?
              change_ident = SvnRecord::Repository::Change.where(revision: identifiers).dup.group_by(&:revision)
              entries_with_identifier.each {|entry| entry.changeset = change_indent[entry.lastrev.identifier] if change_indent[entry.lastrev.identifier] }
            end
          end

        private

        def strip_credential(cmd,q = "'")
          cmd.to_s.gsub(/(\-\-(password|username))\s+(#{q}[^#{q}]+#{q}|[^#{q}]\S+)/, '\\1 xxxx')
        end

        def shell_quote(str)
          "'" + str.gsub(/'/, "'\"'\"'") + "'"
        end

        def target(path = '')
          base = path.match(/^\//) ? root_url : url
          uri = "#{base}/#{path}"
          uri = URI.escape(URI.escape(uri), '[]')
          shell_quote(uri.gsub(/[?<>\*]/, ''))
        end

        def credentials_string
          str = ''
          str << " --username #{shell_quote(@login)}" unless @login.blank?
          str << " --password #{shell_quote(@password)}" unless @login.blank? || @password.blank?
          str << " --no-auth-cache --non-interactive"
          str
        end
        
        def each_xml_element(node, name, &block)
          node[name].is_a?(Hash) ? yield(node[name]) : node[name].each{|element| yield(element)} if node && node[name]
        end
        
        def parse_xml(xml)
          ActiveSupport::XmlMini.parse(xml)
        end
      end
      
      class Entries < Array
        def sort_by_name
          dup.sort! {|x,y| x.kind == y.kind ? x.name.to_s <=> y.name.to_s : x.kind <=> y.kind}
        end

        def revisions
          revisions ||= Revisions.new(collect{|entry| entry.lastrev}.compact)
        end
      end

      class Info
        attr_accessor :root_url, :lastrev
        def initialize(attributes={})
          self.root_url = attributes[:root_url] if attributes[:root_url]
          self.lastrev = attributes[:lastrev]
        end
        def self.get_instance(doc)
          new({:root_url => doc['info']['entry']['repository']['root']['__content__'],
            :lastrev => Revision.new({
              :identifier => doc['info']['entry']['commit']['revision'],
              :time => Time.parse(doc['info']['entry']['commit']['date']['__content__']).localtime,
              :author => (doc['info']['entry']['commit']['author'] ? doc['info']['entry']['commit']['author']['__content__'] : "")
            })
          })
        end
      end

      class Entry
        attr_accessor :name, :path, :kind, :size, :lastrev, :changeset
        def initialize(attributes={}) 
          self.name = attributes[:name] if attributes[:name]
          self.path = attributes[:path] if attributes[:path]
          self.kind = attributes[:kind] if attributes[:kind]
          self.size = attributes[:size].to_i if attributes[:size]
          self.lastrev = attributes[:lastrev]
        end
        def is_file?
          'file' == self.kind
        end
        def is_dir?
          'dir' == self.kind
        end
      end

      class Revisions < Array
        def latest
          sort {|x,y|
            unless x.time.nil? or y.time.nil?
              x.time <=> y.time
            else
              0
            end
            }.last
          end
        end

        class Revision
          attr_accessor :scmid, :name, :author, :time, :message,
          :paths, :revision, :branch, :identifier,:parents

          def initialize(attributes={})
            self.identifier = attributes[:identifier]
            self.scmid      = attributes[:scmid]
            self.name       = attributes[:name] || self.identifier
            self.author     = attributes[:author]
            self.time       = attributes[:time]
            self.message    = attributes[:message] || ""
            self.paths      = attributes[:paths]
            self.revision   = attributes[:revision]
            self.branch     = attributes[:branch]
            self.parents    = attributes[:parents]
          end

          # Returns the readable identifier.
          def format_identifier
            self.identifier.to_s
          end

          def ==(other)
            if other.nil?
              false
            elsif scmid.present?
              scmid == other.scmid
            elsif identifier.present?
              identifier == other.identifier
            elsif revision.present?
              revision == other.revision
            end
          end 
        end
      end
    end
  end
