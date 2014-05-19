
require 'yaml'
require 'set'

require 'util'

class AbstractConfig

  class FieldType
    attr_reader :name, :description

    def initialize(name, type, desc)
      @name = name
      @type = type
      @desc = desc

      # Sanity check on allowed types
      raise IIError, "Unsupported type: #{type}." unless
        @type.class == Array || [Fixnum, String].include?(@type)
    end

    def initval
      return @type[0]   if @type.class == Array
      return 0          if @type == Fixnum
      return ""         if @type == String
      
      raise IIError, "Inknown field type."
    end

    def legalval?(value)
      return @type.include?(value) if @type.class == Array
      return value.class == @type
    end

    def typename
      return "a " + @type.to_s if @type.class == Class
      return "one of " + @type.map{|t| "'#{t}'"}.join(",")
    end
  end

  def initialize
    @fields = {}
    @types = {}

    knownfields.each{|k, t, d| 
      type = FieldType.new(k,t,d)
      @types[k] = type
      @fields[k] = type.initval
    }
  end

  def [](key)
    key = key.intern
    raise IIError, "Invalid config key '#{key}'" unless @types.has_key?(key)
    return @fields[key]
  end

  def []=(key, value)
    key = key.intern    # tolerate string keys
    raise IIUserError, "Invalid config key '#{key}'" unless
      @types.has_key?(key)

    msg = "Illegal value for config item #{key}: '#{value}'." + 
      "  Expecting #{@types[key].typename}"
    raise IIUserError, msg unless @types[key].legalval?(value)

    return @fields[key] = value
  end

  def keys
    return @fields.keys
  end

  def load!(path)
    guessValues!    # ensure sane initial values

    newfields = load_yaml(path)
    if !newfields
      return false
    end

    # Copy only the known keys, using [] to validate types.  A
    # tampered-with config file will fail and invalid keys will be
    # ignored.
    @fields.keys.each{|k| self[k] = newfields[k]}

    return true
  end

  def save(path)
    iowrap {
      File.open(path, "w") { |fh| fh.write(@fields.to_yaml) }
    }
    return nil
  end

  private

  def load_yaml(path)
    fields = nil
    File.open(path, "r") {|fh| fields = YAML.load(fh.read)}
    return fields
  rescue Psych::SyntaxError => se
    raise IIUserError, "Syntax error in '#{path}': #{se.message}"
  rescue IOError,SystemCallError => e
    return nil
  end

  def knownfields
    #return []
    raise "Abstract method called."
  end

  def guessValues!
    raise "Abstract method called."
  end

end


class GlobalConfig < AbstractConfig

  private

  def knownfields
    return [
            [:editor,      String, "Path to preferred text editor"],
            [:git,         String, "Path to 'git' executable"],
            [:browser,     String, "Path to preferred web browser"],
           ]
  end

  def guessValues!
    self[:editor] = ENV['VISUAL'] || which("vi") || ""
    self[:git] = which("git") || ""
    self[:browser] = ENV['BROWSER'] || which("firefox") || which("chrome") || ""

    return nil
  end

  # Return the absolute path to 'cmd'
  # Source: http://stackoverflow.com/questions/2108727
  def which(cmd)
    exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
    ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
      exts.each { |ext|
        exe = File.join(path, "#{cmd}#{ext}")
        return exe if File.executable? exe
      }
    end
    return nil
  end
end


class BlogConfig < AbstractConfig

  private

  def guessValues!
    self[:title] = "My Blog"
    self[:subtitle] = "A Blog About Stuff"
    self[:copyright] = "Contents Copyright &#160;&#169;&#160; " + 
      "#{Time.now.year}.  All Rights Reserved."
    self[:disclaimer] = "The contents of this blog are the author's " +
      "opinion only."
    self[:navbar] =
      "Home|{{rootpath}}/index.html||" + 
      "RSS Feed|{{rss_link}}||" +
      "Archives|{{archive_link}}"
    self[:pagesize] = 5
    self[:rss] = 'rss2.0'

    self[:recent_count] = 10
   
    self[:no_intra_emphasis] = true
    self[:quotes] = true
    self[:footnotes] = false
    self[:base_url] = 'http://localhost/'
    self[:upload_cmd] = '/bin/false'
    self[:template] = 'default'

    return nil
  end

  def knownfields
    bool = [false, true]
    return [
            [:title,               String, "Blog's title"],
            [:subtitle,            String, "Blog's subtitle"],
            [:copyright,           String, "Blog's copyright message."],
            [:disclaimer,          String, "Brief disclaimer."],
            [:navbar,              String, "Navigation bar entries."],
            [:pagesize,            Fixnum, "Number of articles on front page"],
            [:rss,                 ["", "rss1.0", "rss2.0"], 
                                           "RSS version to use, if any"],
            [:no_intra_emphasis,     bool, "Markdown ignores '_' in a word"],
            [:quotes,                bool, "Markdown parses quotes"],
            [:footnotes,             bool, "Markdown parses footnotes"],
            [:base_url,            String, "URL of blog root."],
            
            [:recent_count,        Fixnum, "Num. Articles in 'recent' pane"],
            [:author,              String, "Author's name"],
            [:upload_cmd,          String, "Program to upload contents"],
            [:template,            String, "URL of template to use."],
           ]
  end
end
