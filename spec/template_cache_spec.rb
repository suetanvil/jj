
require 'spec_helper'



describe Storage do
  before :each do
    @root = "tmp_template_test"
    Dir.mkdir(@root)

    @git = Git.new('not-really-git', false)
    def @git.git(*cmd)
      @count = 0 if @count == nil
      @count += 1
    end

    def @git.count
      @count
    end

    def @git.clone(url, dest)
      Dir.mkdir(dest)
      Dir.mkdir(File.join(dest, 'template'))
      @count += 1
    end

    @git.push   # init count

    @got_url = 'git@github.com:/foo/bar/quux.git'
    @gone_url = 'git@github.com:/baz/bobo/narf.git'
    @cache = TemplateCache.new(@root, @git, ".")
    @cache.setup(true)
    @cache.fetch(@got_url)
  end

  after :each do
    FileUtils.rm_rf(@root)
  end

  it "fetches a theme via git if not already present" do
    path = @cache.path_to(@gone_url)
    gc = @git.count
    File.exist?(path).should be false   # check for stale root
    @git.count.should equal gc

    @cache.fetch(@gone_url)
    @git.count.should equal(gc + 1)

    Dir.exist?(path).should be true
  end

  it "tests if the template is present in the cache" do
    @cache.has?(@got_url).should be true
    @cache.has?(@gone_url).should be false
  end

  it "does not fetch if the template is present" do
    gc = @git.count
    @cache.fetch(@got_url)
    @git.count.should equal gc
  end

  it "returns to path to template members" do
    path = @cache.path_to(@got_url, "foo.tpl")
    File.exist?(path).should be false
    File.exist?(File.dirname(path)).should be true

    @cache.path_to(@got_url).should eq File.dirname(path)
  end

  it "can pull the latest version of a template from git" do
    gc = @git.count
    @cache.freshen
    @git.count.should be > gc
  end
  
  it "can clear the template cache" do
    @cache.has?(@got_url).should be true
    @cache.clear
    @cache.has?(@got_url).should be false
    Dir.exist?(@cache.path_to(@got_url)).should be false
  end

end
