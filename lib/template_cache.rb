require 'uri'
require 'fileutils.rb'

class TemplateCache
  TPL_DIR = 'template_cache'
  TPL_CONTENT_DIR = "template"
  TPL_DEFAULT = 'default'

  def initialize(cfgroot, git, approot)
    @cfgroot = File.absolute_path(cfgroot)
    @workdir = File.join(cfgroot, TPL_DIR)
    @git = git
    @approot = approot
  end

  def setup(silent = false)
    make_cache_dir(silent)
  end

  def fetch(url)
    return true if url == TPL_DEFAULT
    dir = mungedUrl(url)
    success = false
    Dir.chdir(@workdir) {
      clone_url(url, dir) unless Dir.exist?(dir)
      success = Dir.exist?(dir)      
    }
    return success
  end

  def path_to(url, file = "")
    dir = path_to_url(url)
    dir = File.join(dir, file) if file != ""
    return dir
  end


  def has?(url)
    return true if url == TPL_DEFAULT
    return Dir.exist?(path_to(url))
  end

  def freshen
    errors = []
    ls_cache.each do |path|
      Dir.chdir(File.join(@workdir, path)) do
        begin
          @git.pull()
        rescue IIError => e
          errors.push "Error updating template '#{unmungedUrl(path)}':" + 
            " #{e.message}"
        end
      end
    end
    return errors
  end

  # def cached
  #   return ls_cache.map{|dir| unmungedUrl(dir)}
  # end

  def clear
    iowrap{FileUtils.rm_rf(@workdir)}
    return true
  end

  private

  def clone_url(url, dir)
    if url == TPL_DEFAULT
      FileUtils.cp_r(File.join($JJ_INSTDIR, 'templates', TPL_DEFAULT), dir)
      return
    end

    @git.clone(url, dir)
  end

  def ls_cache
    return Dir.foreach(@workdir).select{ |path|
      path != '.' && path != '..' && Dir.exist?(File.join(@workdir, path)) &&
        Dir.exist?(File.join(@workdir, path, TPL_CONTENT_DIR))
    }
  end

  def copyLocal(url)
    FileUtil.rm_rf(SiteBuilder::TEMPLATE_DIR)
    FileUtil.cp_r(File.join(@workdir, mungedUrl(url)),
                  SiteBuilder::TEMPLATE_DIR)
  end

  def mungedUrl(url)
    return URI.escape(url, /[^-_a-zA-Z0-9.]/)
  end

  def unmungedUrl(url)
    return URI.unescape(url)
  end

  def path_to_url(url)
    return File.join($JJ_INSTDIR, 'templates', TPL_DEFAULT) if url == TPL_DEFAULT
    return File.join(@workdir, mungedUrl(url), TPL_CONTENT_DIR)
  end

  def make_cache_dir(silent)
    if !Dir.exist?(@workdir)
      iowrap {Dir.mkdir(@workdir)}
      puts "Created directory '#{@workdir}'" unless silent
    end
  end
end
