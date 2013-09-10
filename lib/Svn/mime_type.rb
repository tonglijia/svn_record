module Svn
  module MimeType
    
    MIME_TYPES = {
      'text/css' => 'css',
      'text/html' => 'html,htm,xhtml',
      'text/x-html-template' => 'rhtml',
      'text/x-ruby' => 'rb,rbw,ruby,rake,erb',
      'text/x-sh' => 'sh',
      'text/csv' => 'csv',
      'image/gif' => 'gif',
      'image/jpeg' => 'jpg,jpeg,jpe',
      'image/png' => 'png',
      'image/tiff' => 'tiff,tif',
      'image/x-ms-bmp' => 'bmp',
      'image/x-xpixmap' => 'xpm',
      'image/svg+xml'=> 'svg',
      'application/javascript' => 'js',
      'application/vnd.ms-powerpoint' => 'ppt,pps',
      'application/x-tar' => 'tar',
      'application/zip' => 'zip',
      'application/x-gzip' => 'gz',
      }.freeze
      
      EXTENSIONS = MIME_TYPES.inject({}) do |map, (type, exts)|
        exts.split(',').each {|ext| map[ext.strip] = type}
        map
      end
      
      # returns mime type for name or nil if unknown
      def self.of(name)
        return nil unless name
        m = name.to_s.match(/(^|\.)([^\.]+)$/)
        EXTENSIONS[m[2].downcase] if m
      end
      
      # Returns the css class associated to
      # the mime type of name
      def self.css_class_of(name)
        mime = of(name)
        mime && mime.gsub('/', '-')
      end
      
      def self.main_mimetype_of(name)
        mimetype = of(name)
        mimetype.split('/').first if mimetype
      end
      
      # return true if mime-type for name is type/*
      # otherwise false
      def self.is_type?(type, name)
        main_mimetype = main_mimetype_of(name)
        type.to_s == main_mimetype
      end
    end
    
  module SyntaxHighlighting
    
    class << self
      attr_reader :highlighter
      delegate :highlight_by_filename, :highlight_by_language, :to => :highlighter
      
      def highlighter=(name)
        if name.is_a?(Module)
          @highlighter = name
        else
          @highlighter = const_get(name)
        end
      end
    end
    module CodeRay
      require 'coderay'
      require 'coderay/helpers/file_type'
      class << self
        # Highlights +text+ as the content of +filename+
        # Should not return line numbers nor outer pre tag
        def highlight_by_filename(text, filename)
          language = ::CodeRay::FileType[filename]
          language ? ::CodeRay.scan(text, language).html(:break_lines => true) : ERB::Util.h(text)
        end
        # Highlights +text+ using +language+ syntax
        # Should not return outer pre tag
        def highlight_by_language(text, language)
          ::CodeRay.scan(text, language).html(:wrap => :span)
        end
      end
    end
  end
  SyntaxHighlighting.highlighter = 'CodeRay'
  
  class UnifiedDiff < Array
    attr_reader :diff_type, :diff_style
    
    def initialize(diff, options={})
      options.assert_valid_keys(:type, :style, :max_lines)
      diff = diff.split("\n") if diff.is_a?(String)
      @diff_type = options[:type] || 'inline'
      @diff_style = options[:style]
      lines = 0
      @truncated = false
      diff_table = DiffTable.new(diff_type, diff_style)
      diff.each do |line_raw|
        line = Svn::CodesetUtil.to_utf8_by_setting(line_raw)
        unless diff_table.add_line(line)
          self << diff_table if diff_table.length > 0
          diff_table = DiffTable.new(diff_type, diff_style)
        end
        lines += 1
        if options[:max_lines] && lines > options[:max_lines]
          @truncated = true
          break
        end
      end
      self << diff_table unless diff_table.empty?
      self
    end
    def truncated?; @truncated; end
  end
  
  # Class that represents a file diff
  class DiffTable < Array
    attr_reader :file_name
    def initialize(type="inline", style=nil)
      @parsing = false
      @added = 0
      @removed = 0
      @type = type
      @style = style
      @file_name = nil
      @git_diff = false
    end
    
    def add_line(line)
      unless @parsing
        if line =~ /^(---|\+\+\+) (.*)$/
          self.file_name = $2
        elsif line =~ /^@@ (\+|\-)(\d+)(,\d+)? (\+|\-)(\d+)(,\d+)? @@/
          @line_num_l = $2.to_i
          @line_num_r = $5.to_i
          @parsing = true
        end
      else
        if line =~ %r{^[^\+\-\s@\\]}
          @parsing = false
          return false
        elsif line =~ /^@@ (\+|\-)(\d+)(,\d+)? (\+|\-)(\d+)(,\d+)? @@/
          @line_num_l = $2.to_i
          @line_num_r = $5.to_i
        else
          parse_line(line, @type)
        end
      end
      return true
    end
    def each_line
      prev_line_left, prev_line_right = nil, nil
      each do |line|
        spacing = prev_line_left && prev_line_right && (line.nb_line_left != prev_line_left+1) && (line.nb_line_right != prev_line_right+1)
        yield spacing, line
        prev_line_left = line.nb_line_left.to_i if line.nb_line_left.to_i > 0
        prev_line_right = line.nb_line_right.to_i if line.nb_line_right.to_i > 0
      end
    end
    
    def inspect
      puts '### DIFF TABLE ###'
      puts "file : #{file_name}"
      self.each do |d|
        d.inspect
      end
    end
    
    private
    
    def file_name=(arg)
      both_git_diff = false
      if file_name.nil?
        @git_diff = true if arg =~ %r{^(a/|/dev/null)}
      else
        both_git_diff = (@git_diff && arg =~ %r{^(b/|/dev/null)})
      end
      if both_git_diff
        if file_name && arg == "/dev/null"
          # keep the original file name
          @file_name = file_name.sub(%r{^a/}, '')
        else
          # remove leading b/
          @file_name = arg.sub(%r{^b/}, '')
        end
      elsif @style == "Subversion"
        # removing trailing "(revision nn)"
        @file_name = arg.sub(%r{\t+\(.*\)$}, '')
      else
        @file_name = arg
      end
    end
    
    def diff_for_added_line
      if @type == 'sbs' && @removed > 0 && @added < @removed
        self[-(@removed - @added)]
      else
        diff = Diff.new
        self << diff
        diff
      end
    end
    
    def parse_line(line, type="inline")
      if line[0, 1] == "+"
        diff = diff_for_added_line
        diff.line_right = line[1..-1]
        diff.nb_line_right = @line_num_r
        diff.type_diff_right = 'diff_in'
        @line_num_r += 1
        @added += 1
        true
      elsif line[0, 1] == "-"
        diff = Diff.new
        diff.line_left = line[1..-1]
        diff.nb_line_left = @line_num_l
        diff.type_diff_left = 'diff_out'
        self << diff
        @line_num_l += 1
        @removed += 1
        true
      else
        write_offsets
        if line[0, 1] =~ /\s/
          diff = Diff.new
          diff.line_right = line[1..-1]
          diff.nb_line_right = @line_num_r
          diff.line_left = line[1..-1]
          diff.nb_line_left = @line_num_l
          self << diff
          @line_num_l += 1
          @line_num_r += 1
          true
        elsif line[0, 1] = "\\"
          true
        else
          false
        end
      end
    end
    
    def write_offsets
      if @added > 0 && @added == @removed
        @added.times do |i|
          line = self[-(1 + i)]
          removed = (@type == 'sbs') ? line : self[-(1 + @added + i)]
          offsets = offsets(removed.line_left, line.line_right)
          removed.offsets = line.offsets = offsets
        end
      end
      @added = 0
      @removed = 0
    end
    
    def offsets(line_left, line_right)
      if line_left.present? && line_right.present? && line_left != line_right
        max = [line_left.size, line_right.size].min
        starting = 0
        while starting < max && line_left[starting] == line_right[starting]
          starting += 1
        end
        while line_left[starting].ord.between?(128, 191) && starting > 0
          starting -= 1
        end
        ending = -1
        while ending >= -(max - starting) && line_left[ending] == line_right[ending]
          ending -= 1
        end
        while line_left[ending].ord.between?(128, 191) && ending > -1
          ending -= 1
        end
        unless starting == 0 && ending == -1
          [starting, ending]
        end
      end
    end
  end

  # A line of diff
  class Diff
    attr_accessor :nb_line_left
    attr_accessor :line_left
    attr_accessor :nb_line_right
    attr_accessor :line_right
    attr_accessor :type_diff_right
    attr_accessor :type_diff_left
    attr_accessor :offsets

    def initialize()
      self.nb_line_left = ''
      self.nb_line_right = ''
      self.line_left = ''
      self.line_right = ''
      self.type_diff_right = ''
      self.type_diff_left = ''
    end

    def type_diff
      type_diff_right == 'diff_in' ? type_diff_right : type_diff_left
    end

    def line
      type_diff_right == 'diff_in' ? line_right : line_left
    end

    def html_line_left
      line_to_html(line_left, offsets)
    end

    def html_line_right
      line_to_html(line_right, offsets)
    end

    def html_line
      line_to_html(line, offsets)
    end

    def inspect
      puts '### Start Line Diff ###'
      puts self.nb_line_left
      puts self.line_left
      puts self.nb_line_right
      puts self.line_right
    end

    private

    def line_to_html(line, offsets)
      html = line_to_html_raw(line, offsets)
      html.force_encoding('UTF-8') if html.respond_to?(:force_encoding)
      html
    end

    def line_to_html_raw(line, offsets)
      if offsets
        s   = ''
        unless offsets.first == 0
          s << CGI.escapeHTML(line[0..offsets.first-1])
        end
        s << '<span>' + CGI.escapeHTML(line[offsets.first..offsets.last]) + '</span>'
        unless offsets.last == -1
          s << CGI.escapeHTML(line[offsets.last+1..-1])
        end
        s
      else
        CGI.escapeHTML(line)
      end
    end
  end

  module CodesetUtil

    def self.replace_invalid_utf8(str)
      return str if str.nil?
      if str.respond_to?(:force_encoding)
        str.force_encoding('UTF-8')
        if ! str.valid_encoding?
          str = str.encode("US-ASCII", :invalid => :replace,
          :undef => :replace, :replace => '?').encode("UTF-8")
        end
      elsif RUBY_PLATFORM == 'java'
        begin
          ic = Iconv.new('UTF-8', 'UTF-8')
          str = ic.iconv(str)
        rescue
          str = str.gsub(%r{[^\r\n\t\x20-\x7e]}, '?')
        end
      else
        ic = Iconv.new('UTF-8', 'UTF-8')
        txtar = ""
        begin
          txtar += ic.iconv(str)
        rescue Iconv::IllegalSequence
          txtar += $!.success
          str = '?' + $!.failed[1,$!.failed.length]
          retry
        rescue
          txtar += $!.success
        end
        str = txtar
      end
      str
    end

    def self.to_utf8(str, encoding)
      return str if str.nil?
      str.force_encoding("ASCII-8BIT") if str.respond_to?(:force_encoding)
      if str.empty?
        str.force_encoding("UTF-8") if str.respond_to?(:force_encoding)
        return str
      end
      enc = encoding.blank? ? "UTF-8" : encoding
      if str.respond_to?(:force_encoding)
        if enc.upcase != "UTF-8"
          str.force_encoding(enc)
          str = str.encode("UTF-8", :invalid => :replace,
          :undef => :replace, :replace => '?')
        else
          str.force_encoding("UTF-8")
          if ! str.valid_encoding?
            str = str.encode("US-ASCII", :invalid => :replace,
            :undef => :replace, :replace => '?').encode("UTF-8")
          end
        end
      elsif RUBY_PLATFORM == 'java'
        begin
          ic = Iconv.new('UTF-8', enc)
          str = ic.iconv(str)
        rescue
          str = str.gsub(%r{[^\r\n\t\x20-\x7e]}, '?')
        end
      else
        ic = Iconv.new('UTF-8', enc)
        txtar = ""
        begin
          txtar += ic.iconv(str)
        rescue Iconv::IllegalSequence
          txtar += $!.success
          str = '?' + $!.failed[1,$!.failed.length]
          retry
        rescue
          txtar += $!.success
        end
        str = txtar
      end
      str
    end

    def self.to_utf8_by_setting(str)
      return str if str.nil?
      str = self.to_utf8_by_setting_internal(str)
      if str.respond_to?(:force_encoding)
        str.force_encoding('UTF-8')
      end
      str
    end

    def self.to_utf8_by_setting_internal(str)
      return str if str.nil?
      if str.respond_to?(:force_encoding)
        str.force_encoding('ASCII-8BIT')
      end
      return str if str.empty?
      return str if /\A[\r\n\t\x20-\x7e]*\Z/n.match(str) # for us-ascii
      if str.respond_to?(:force_encoding)
        str.force_encoding('UTF-8')
      end
      str = self.replace_invalid_utf8(str)
      if str.respond_to?(:force_encoding)
        str.force_encoding('UTF-8')
      end
      str
    end

    def self.from_utf8(str, encoding)
      str ||= ''
      if str.respond_to?(:force_encoding)
        str.force_encoding('UTF-8')
        if encoding.upcase != 'UTF-8'
          str = str.encode(encoding, :invalid => :replace,
          :undef => :replace, :replace => '?')
        else
          str = self.replace_invalid_utf8(str)
        end
      elsif RUBY_PLATFORM == 'java'
        begin
          ic = Iconv.new(encoding, 'UTF-8')
          str = ic.iconv(str)
        rescue
          str = str.gsub(%r{[^\r\n\t\x20-\x7e]}, '?')
        end
      else
        ic = Iconv.new(encoding, 'UTF-8')
        txtar = ""
        begin
          txtar += ic.iconv(str)
        rescue Iconv::IllegalSequence
          txtar += $!.success
          str = '?' + $!.failed[1, $!.failed.length]
          retry
        rescue
          txtar += $!.success
        end
        str = txtar
      end
    end
  end
end
