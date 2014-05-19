
require 'fileutils'
require 'liquid'
require 'rss'
require 'nokogiri'

require 'blogaction'

class SiteBuilder
  SITE          = 'rendered'

  FEED_FILE     = 'rss-feed.xml'

  ARTICLE_TPL   = 'article_template.tpl'
  MAIN_TPL      = 'main_template.tpl'
  RECENT_TPL    = 'recent_template.tpl'
  ARCHIVE_TPL   = 'archive_template.tpl'

  ART_SCRIPT    = 'article_script.tpl'      # expanded inside each article
  HDR_SCRIPT    = 'header_script.tpl'       # expands in header of each page
  BODY_SCRIPT   = 'body_script.tpl'         # expands in body of each page

  def initialize(storage, cfg, tpl_cache)
    @storage = storage
    @baseurl = cfg[:base_url].sub(/\/*$/, '')
    @cfg = cfg
    @tpl_cache = tpl_cache

    @templates = {}
    @navbar_cache = nil
  end

  def clear
    return unless @storage.inBlogDir?   # Redundant; guard against data loss
    FileUtils.rm_rf(SITE)
  end
  
  def render
    msg "Beginning render..."
    clear_if_needed()
    setup_template()
    check_env()
    setup_site()

    update_list = render_articles()
    if update_list.size == 0 && @storage.published_ids.size > 0
      msg "Nothing to do.  Quitting."
      return []
    end

    msg "Rendering list pages."
    render_frontpage()
    render_archive()
    render_syndication()

    msg "Copying support html from the template."
    copy_html()

    return update_list
  end

  def article_template;     return tpl(ARTICLE_TPL);                end
  def main_template;        return tpl(MAIN_TPL);                   end
  def recent_template;      return tpl(RECENT_TPL);                 end
  def archive_template;     return tpl(ARCHIVE_TPL);                end

  def art_script_template;  return tpl(ART_SCRIPT, true, true);     end
  def hdr_script_template;  return tpl(HDR_SCRIPT, true, true);     end
  def body_script_template; return tpl(BODY_SCRIPT, true, true);    end

  private

  # Clear the current render if it turns out the entire site may be
  # stale.
  def clear_if_needed
    clear() if Dir.exist?(SITE) && @storage.mtime_cfgfile > File.mtime(SITE)
  end

  def setup_template
    @tpl_cache.fetch(@cfg[:template]) or
      raise IIUserError, "Unable to fetch template '#{@cfg[:template]}'"
  end

  def check_env
    curr = ''
    [ARTICLE_TPL, MAIN_TPL, RECENT_TPL, ARTICLE_TPL].each{|t| curr = t; tpl(t)}
  rescue IIError
    raise IIUserError, "Corrupt or missing template file '#{curr}' in " +
      "'#{@cfg[:template]}'"
  end

  # Read, parse and return the template at 'tplFile', using a cached
  # version if a previous call had already loaded it.  If
  # 'allowMissing' is true, an ampty template is returned if the file
  # is missing.  Prepends the template directory unless 'fullpath' is
  # true.
  def tpl(tplFile, allowMissing = false, fullpath = false)
    tplFile = @tpl_cache.path_to(@cfg[:template], tplFile) unless fullpath
    return @templates[tplFile] if @templates.has_key?(tplFile)
    return @templates[tplFile] = tpl_slurp(tplFile, allowMissing)
  end

  def setup_site
     Dir.mkdir(SITE) unless Dir.exist?(SITE)
  end

  def render_articles
    return @storage.published_ids.select{|id| 
      render_article_id(id)     | # not short-circuited!
      update_attachments(id)
    }
  end

  def update_attachments(id)
    files = @storage.attachments(id)
    return false unless files.size > 0

    updated = false
    for src in files
      dest = File.join(dest_path_to_article(id), File.basename(src))
      next unless !File.exist?(dest) || File.mtime(src) > File.mtime(dest)

      msg "copy #{src} -> #{dest}"
      iowrap {FileUtils.cp(src, dest)}
      updated = true
    end

    return updated
  end

  def render_article_id(id)
    article = @storage.get(id)
    dirname, filename = path_to_article(id, article)

    fulldir = dest_path_to_article(id)   #File.join(SITE, dirname)
    fullfilename = File.join(SITE, dirname, filename)

    # Quit now if the article appears to be unchanged (i.e. the
    # rendered html file is not older than the latest version of the
    # article.
    return false if
      File.exist?(fullfilename) && 
      File.mtime(fullfilename) >= @storage.mtime(id)

    msg "Rendering #{dirname}/#{filename}"

    # Emit body html
    text = basic_render_article(article, filename, true, id)

    # Wrap with page html
    text = main_wrap(text, '..', true)

    # Create the article directory if necessary.
    Dir.mkdir(fulldir) unless Dir.exist?(fulldir)

    unslurp(fullfilename, text)
    unslurp(File.join(fulldir, "index.html"), redirect_html(filename))

    return true
  end

  # Return html for article at 'path'
  def basic_render_article(article, path, standalone, id)
    attach_dir = standalone ? "." : File.dirname(path)
    contents = replace_content_path(article.contents_rendered, attach_dir)

    fields = {
      'rich_subject' => article.subject_rendered,
      'subject'      => article.subject,
      'contents'     => contents,
      'modify_date'  => article.date,
      'creation_date'=> article.creationDate,
      'pub_date'     => article.publishDate,
      'permalink'    => path,
      'content_path' => attach_dir,
      'standalone'   => standalone,
      'id'           => @storage.id2file_base(id)
    }

    art_script = art_script_template.render(fields)
    fields['art_script'] = art_script

    return article_template.render(fields)
  end

  # Go through htmlText and replace the tag string ('$CONTENT_PATH')
  # with the value of attach_dir in those tag attributes that could
  # refer to an attached object.
  def replace_content_path(htmlText, attach_dir)
    doc = Nokogiri::HTML.parse(htmlText)

    expandables = [ ['href', %w{a link area}],
                    ['data', %w{object}],
                    ['src', %w{script img}] ]

    for e in expandables
      attrib, tags = e
      for t in tags
        doc.css(t).each do |node|
          node[attrib] = node[attrib].gsub(/\$CONTENT_PATH/x, attach_dir)
        end
      end
    end

    return doc.to_html()
  end

  # Return the dirname and filename of the article at id
  def path_to_article(id, article)
    dirname = @storage.id2file_base(id)
    filename = article.subject_sanitized + '.html'

    return [dirname, filename]
  end

  def dest_path_to_article(id)
    root = @storage.id2file_base(id)
    return File.join(SITE, root)
  end


  def render_frontpage
    articles = []
    for id in @storage.published_ids.reverse[0 .. @cfg[:pagesize]-1]
      article = @storage.get(id)

      dirname, filename = path_to_article(id, article)
      text = basic_render_article(article, dirname + '/' + filename, false, id)

      articles.push text
    end

    body = main_wrap(articles.join("\n"), ".", false)
    unslurp(File.join(SITE, "index.html"), body)
  end

  def render_archive
    art_list = linklist(0, @storage.published_ids.size - 1,
                        archive_template, ".")
    body = main_wrap(art_list, ".", false)
    unslurp(File.join(SITE, "archive.html"), body)
  end

  def render_syndication
    return if @cfg[:rss] == ""

    # As RSS::Maker is virtually undocumented and too full of
    # spaghetti inheritance to actually read, I'm kind of muddling
    # around in the dark here.  I got this to work by running the
    # code, then adding a line to set the next field it complained
    # about being missing.  (There is no list of supported or required
    # fields--no, I'm not bitter or anything.)  It will also generate
    # Atom, but the html sanitization phase makes the results
    # unreadable.
    #
    # So, TODO: write a proper syndication module.  In the meantime...

    rss = RSS::Maker.make(@cfg[:rss]) do |maker|
      maker.channel.title = @cfg[:title]
      maker.channel.author = @cfg[:author]
      maker.channel.link = @cfg[:base_url]
      maker.channel.description = @cfg[:subtitle]
      maker.channel.updated = Time.now.to_s
      maker.channel.about = @cfg[:base_url]

      for id in @storage.published_ids.reverse[0 .. @cfg[:pagesize] - 1]
        article = @storage.get(id)
        dirname, filename = path_to_article(id, article)

        maker.items.new_item do |item|
          item.title = article.subject
          item.link = "#{@cfg[:base_url]}/#{dirname}/#{filename}"
          item.description = article.contents_rendered
          item.guid.content = @storage.id2file_base(id)
          item.updated = article.date
        end
      end
    end

    unslurp(File.join(SITE, FEED_FILE), rss)
  end

  def copy_html
    Dir.foreach(@tpl_cache.path_to(@cfg[:template])) do |fn|
      path = @tpl_cache.path_to(@cfg[:template], fn)
      FileUtils.cp(path, SITE) unless
        File.ftype(path) != "file" || fn.match(/\.tpl$/)
    end
  end

  # Wrap 'bodyText' in the outer template.  'standalone' is true if
  # this is a single article, false otherwise.
  def main_wrap(bodyText, rootpath, standalone)
    llend = (@storage.published_ids.size - 1) - @cfg[:pagesize]
    llstart = [llend + 1 - @cfg[:recent_count], 0].max

    fields = {
      'title'          => @cfg[:title],
      'richtitle'      => @cfg[:title],         # Should we render this?
      'author'         => @cfg[:author],
      'subtitle'       => @cfg[:subtitle],
      'copyright'      => @cfg[:copyright],
      'disclaimer'     => @cfg[:disclaimer],
      'links'          => [],                   # filled in later

      'recent_links'   => linklist(llstart, llend,
                                   recent_template,
                                   rootpath),

      'content'        => bodyText,
      
      'rootpath'       => rootpath,
      
      'archive_link'   => "#{rootpath}/archive.html",

      'rss_link'       => "#{rootpath}/#{FEED_FILE}",

      'standalone'     => standalone,
    }

    navbar = navigation(fields)
    fields['links'] = navbar

    hdr_script = hdr_script_template().render(fields)
    body_script = body_script_template().render(fields)
    fields['hdr_script'] = hdr_script
    fields['body_script'] = body_script

    text = main_template.render(fields)
    return text
  end

  def navigation(fields)
    @navbar_cache = make_navbar(fields) unless @navbar_cache
    return @navbar_cache.map{|k,v| [k.render(fields), v.render(fields)]}
  end

  def make_navbar(fields)
    bar = @cfg[:navbar]
    return [] unless bar.match(/\S/)

    result = []
    for entry in bar.split(/\|\|/)
      label, url = entry.split(/\|/)
      url ||= ''

      result.push [Liquid::Template.parse(label),
                   Liquid::Template.parse(url)]
    end

    return result
  end

  def linklist(first, last, template, rootpath)
    return '&nbsp;' if last < 0

    ids = @storage.published_ids[first .. last]

    articles = ids.reverse.map do |id|
      article = @storage.get(id)
 
      dirname, filename = path_to_article(id, article)
      url = rootpath + '/' + dirname + '/' + filename

      {
        'page_url'     => url,
        'rich_subject' => article.subject_rendered,
        'subject'      => article.subject,
        'pub_date'     => article.publishDate
      }
    end

    return template.render('articles' => articles)
  end

  def tpl_slurp(filename, allowMissing = false)
    return Liquid::Template.parse(slurp(filename, allowMissing))
  end

  def redirect_html(path)
    return <<EOF
<html>
<head>
<title>Redirecting...</title>
<meta http-equiv=\"refresh\" content=\"0; url=#{path}\">
</head>
<body>
The post is <a href="#{path}">here.</a>
</body>
</html>
EOF
  end

end
