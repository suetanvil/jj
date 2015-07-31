
require 'fileutils'
require 'tempfile'

require 'redcarpet'
require 'liquid'

require 'config'
require 'git'
require 'storage'
require 'article'
require 'site_builder'
require 'template_cache'

class BlogAction
  GLOBAL_CFGDIR = File.expand_path('~/.jj')
  CFGFILE='config.yml'
  GLOBAL_CFGFILE = File.join(GLOBAL_CFGDIR, CFGFILE)

  POSTDIR = "posts"
  RENDER = "render"

  def initialize()
    @globalCfg = nil
    @blogCfg = nil
    @globalCfgDir = ''

    @saveGlobalCfg = false

    @git = nil
    @storage = nil

    @builder = nil

    @templateCache = nil
  end

  def setup(allowNonBlogDir, showGit, cfgdir = "")
    @globalCfgDir = cfgdir != "" ? cfgdir : GLOBAL_CFGDIR
    cfgfile = File.join(@globalCfgDir, CFGFILE)

    msg("Reading global config from #{cfgfile}")
    @globalCfg = GlobalConfig.new
    @saveGlobalCfg = ! @globalCfg.load!(cfgfile)
    msg("Failed to read global config.") if @saveGlobalCfg

    mk_cfg_dir(@globalCfgDir)

    @git = Git.new(@globalCfg[:git], showGit)
    @storage = Storage.new(@git)

    @blogCfg = @storage.get_config()

    raise IIUserError, "This doesn't look like a blog." unless 
      allowNonBlogDir || @storage.inBlogDir?()
    
    Article.class_init(@blogCfg)

    @templateCache = TemplateCache.new(File.expand_path(GLOBAL_CFGDIR), @git,
                                       $JJ_INSTDIR)
    @templateCache.setup()

    @builder = SiteBuilder.new(@storage, @blogCfg, @templateCache)
  end

  def teardown
    savecfg(@globalCfg, File.join(@globalCfgDir, CFGFILE)) if @saveGlobalCfg
  end

  # Perform the 'init' command (i.e. create a blog in the current
  # directory).
  def init
    raise IIUserError, "Current directory is already a blog." if
      @storage.inBlogDir?
    raise IIUserError, "Current directory is not empty." unless dir_empty?(".")

    msg("Creating blog...")
    @storage.create
    msg("Done.")

    return
  end

  def list
    index = 1
    for id in @storage.ids
      article = @storage.get(id)
      yield(index, article.publish, article.subject, 
            @storage.id2file_base(id))
      index += 1
    end

    return
  end

  def edit(index)
    (id, article) = getEditable(index, true)

    msg "Editing #{index}."
    newArticle = runEditorOn(article)

    if newArticle == article || newArticle.contents.match(/\A\s*\z/)
      msg "Article empty or unchanged.  Ignoring."
      return
    end

    @storage.put(id, newArticle)
    warn "WARNING: Article was malformed.  Re-edit to fix." if
      newArticle.malformed

    return
  end

  def attach(index, files)
    raise IIUserError, "No article at #{index}" unless
      index >= 0 && index <= @storage.ids.size

    id = @storage.ids[index - 1]
    @storage.put_attachments(id, files)
  end

  def publish(index, yes=true)
    (id, article) = getEditable(index, false)

    return if article.publish == yes
    
    msg "#{yes ? 'P': 'Unp'}ublishing article \##{index}"
    article.publish = yes
    @storage.put(id, article, "Set publish to #{yes}.")
  end

  def render(launchBrowser = false, showRendered = false)
    rendered = @builder.render()

    if showRendered
      stids = @storage.ids
      rendered.each{ |id|
        puts "#{id} #{stids.index(id)} #{@storage.get(id).subject}"
      } 
    end

    return unless launchBrowser

    @globalCfg[:browser] == "" and
      raise IIUserError, "No browser set."

    path = File.join(SiteBuilder::SITE, "index.html")
    system("#{@globalCfg[:browser]} #{path}") or
      raise IIUserError, "Unable to run browser: '#{@globalCfg[:browser]}'"
  end

  def clean
    msg "Cleaning."
    @builder.clear()
  end

  # Fetch the storable contents of an existing article
  def articleGet(index)
    (id, article) = getEditable(index, false)

    return article.storable
  end

  # Store 'text' as an article at index.  If index <= 0, 'text' is
  # stored as a new article; otherwise, it replaces the existing
  # article.
  def articlePut(index, text)
    (id, article) = getEditable(index, true)

    article = Article.new(text)
    @storage.put(id, article)

    self
  end

  # Attempt to upload contents to remote site
  def upload(dryrun, noRender)
    cmd = @blogCfg[:upload_cmd]
    raise IIUserError, "No upload command set" if cmd == ""

    msg "Preparing to upload via '#{cmd}'"

    render() unless noRender
    raise IIUserError, "No rendered content present." unless
      Dir.exist?(SiteBuilder::SITE)

    cmd.gsub!(/\{\{src_dir\}\}/, SiteBuilder::SITE)

    if dryrun
      warn "Dry run; not running command:\n    #{cmd}\n"
      return self
    end

    warn "CMD: #{cmd}\n-- Output begins\n"
    status = system(cmd)
    warn "-- Output ends"

    raise IIUserError, "Error running command '#{cmd}" unless status

    msg "Success!"
    self
  end

  def freshenTemplates
    clean()
    return @templateCache.freshen()
  end

  def clearTemplates
    @templateCache.clear()
  end

  private

  def getEditable(index, createNew)
    index <= 0 && createNew and
      return [@storage.new_article_id, Article.new] 

    index > 0 && index <= @storage.num_articles or
      raise IIUserError, "No article at #{index}."

    id = @storage.ids[index - 1]
    return [id, @storage.get(id)]
  end

  def runEditorOn(article)
    article.timestamp   # Do this now so that the user can change it

    tmpfile = Tempfile.new(['jj-post-', '.md'])
    tmpfile.write(article.storable)
    tmpfile.close

    Kernel.system("#{@globalCfg[:editor]} #{tmpfile.path}") or
      puts "Error running '#{@globalCfg[:editor]}'"
    
    tmpfile.open
    article = Article.new(tmpfile.each_line.to_a.join(""))
    tmpfile.close
    tmpfile.unlink

    return article
  end

  def savecfg(cfg, path)
    cfg.save(path)
    msg "Saving config file '#{path}'"
  end

  def dir_empty?(path)
    Dir.entries(path).select{|e| e != '.' && e != '..'}.size == 0
  end

  def mk_cfg_dir(cfgdir)
    if !Dir.exist?(cfgdir)
      iowrap {Dir.mkdir(cfgdir)}
      msg "Created directory '#{cfgdir}'"
    end
  end

end


