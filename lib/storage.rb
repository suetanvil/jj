
require 'fileutils'

require 'git'
require 'article'
require 'util'

class Storage

  BASE=36
  CFGFILE='config.yml'
  POSTDIR = "posts"
  ATTACHDIR = "attachments"

  def initialize(git)
    @git = git

    @articles = nil             # List of articles.  Access via method.
    @published_articles = nil   # List of published articles.  Ditto.
  end

  def create
    raise IIError, "create called in blog dir." if inBlogDir?

    hedge = File.join(POSTDIR, "hedge")
    iowrap { Dir.mkdir(POSTDIR) }
    unslurp(hedge, "Ssssssh!  We're a hedge!\n")

    cfg = get_config()
    cfg.save(CFGFILE)

    @git.init
    @git.add(CFGFILE, hedge)
    @git.commit("Initial check-in.  Created blog repo.")
  end

  def num_articles
    return articles.size
  end

  # Return an article ID that is not yet used.
  def new_article_id
    while true
      id = time_now_round()

      # On the off chance that the clock is skewed and this article
      # already exists, we check for it and try again if so.
      break unless has?(id)
    end

    return id
  end

  def ids
    return articles().map{|nm| file2id(nm)}
  end

  def published_ids
    return published_articles().map{|nm| file2id(nm)}
  end

  def has?(id)
    return articles().include?(id2file(id))
  end

  def get(id)
    return nil unless has?(id)

    filename = File.join(POSTDIR, id2file(id))
    text = slurp(filename)

    return Article.new.restore!(text)
  end

  def put(id, article, desc = "")
    filename = File.join(POSTDIR, id2file(id))
    unslurp(filename, article.storable)

    desc = "\n#{desc}" if desc != ""

    @git.add filename
    @git.commit (has?(id) ? "Updated " : "Added ") + 
      "article #{id2file(id)}.#{desc}"

    flush()

    nil
  end

  def put_attachments(id, files)
    attached = copy_attachments(id, files)
    names = attached.map{|a| File.basename(a)}

    attached.each{|atmt| @git.add atmt}
    @git.commit "Attached file(s) to #{id2file(id)}:\n\n#{names.join("\n")}\n"
  end

  # Return a list of paths to attachment files
  def attachments(id)
    dir = attachdir(id)
    return [] unless Dir.exist?(dir)

    return Dir.foreach(dir).
      map{|f| File.join(dir, f)}.
      select{|f| File.file?(f)}
  end

  # Return the filesystem modification time of config file.
  def mtime_cfgfile
    return File.mtime(CFGFILE)
  end

  # Return the filesystem modification time of the file holding 'id'.
  # Note that this is taken from the filesystem itself, not one of the
  # file's headers.
  def mtime(id)
    return nil unless has?(id)
    return File.mtime(File.join(POSTDIR, id2file(id)))
  end

  def get_config()
    result = BlogConfig.new
    result.load!(CFGFILE)
    return result
  end

  def set_config(cfg)
    verb = File.exist?(CFGFILE) ? "Updated" : "Added"

    cfg.save(CFGFILE)
    @git.add(CFGFILE)
    @git.commit("#{verb} config file.")
  end

  def inBlogDir?
    return File.directory?(".git")  &&

      File.exist?(CFGFILE)          &&
      File.stat(CFGFILE).file?      &&
      File.directory?(POSTDIR)
  end

  def id2file_base(id)
    return id.to_s(BASE)
  end

  def id2file(id)
    return id2file_base(id) + ".post"
  end

  def id2file_dir(id)
    return id2file_base(id)
  end

  def file2id(file)
    return file.sub(/\.post$/, '').to_i(BASE)
  end

  def attachdir(id)
    return File.join(ATTACHDIR, id2file_dir(id))
  end

  private

  # Return the list of article file names, sorted.  Caches in @articles
  def articles
    if !@articles
      iowrap do
        @articles = Dir.open(POSTDIR) do |dir|
          dir.select{ |f|
            f =~ /\A[0-9a-z]+\.post\z/ && 
            File.stat(File.join(POSTDIR, f)).file?
          }
        end
      end

      @articles.sort!{|a, b| a.to_i(BASE) <=> b.to_i(BASE)}
    end

    return @articles
  end
    
  def published_articles
    @published_articles ||= articles().select {|f| get(file2id(f)).publish}

    return @published_articles
  end

  def flush
    @articles = nil
    @published_articles = nil
  end

  def time_now_round
    (Time.now.gmtime.to_f * 1000000).round
  end


  # Copy 'files' to the attachments dir. associated w/ 'id'.
  def copy_attachments(id, files)
    path = attachdir(id)
    FileUtils.makedirs(path)

    copiedfiles = []
    undofiles = []
    begin
      for f in files
        d = File.join(path, File.basename(f))
        overwritten = File.exist?(d)

        copiedfiles.push(d)
        undofiles.push(d) unless overwritten
        FileUtils.copy(f, d)
      end
    rescue IOError, SystemCallError => e
      msg = "System error: #{e}"
      begin
        undofiles.each {|d| FileUtils.rm(d)}
      rescue IOError, SystemCallError => inner
        msg += "\nError during cleanup: #{inner}"
      end
      raise IIUserError, msg
    end

    return copiedfiles
  end
end
