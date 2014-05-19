
# Integration tests for the 'jj' program as a whole.

require 'spec_helper'

require 'fileutils'
require 'tmpdir'
require 'open3'

def run(*cmd)
  stdout, stderr, status = Open3.capture3(*cmd)
  status.exitstatus.should be 0
  return stdout
end

describe "jj" do
  before :all do
    @workdir = Dir.mktmpdir()
    @cfgdir =  Dir.mktmpdir()
    @pwd = Dir.pwd
    ENV['PATH'] += ':' + @pwd + '/bin'
    ENV['VISUAL'] = @pwd + '/spec_util/edit.rb'
    Dir.chdir(@workdir)
    #puts "Workdir = #{@workdir} cfgdir=#{@cfgdir}" #; path=#{ENV['PATH']}"
  end

  after :all do
    Dir.chdir(@pwd)
    FileUtils.rm_rf(@workdir)
    FileUtils.rm_rf(@cfgdir)
  end

  it "creates an empty jj blog" do
    run("jj --config #{@cfgdir} init")
    for d in %w{.git posts}
      Dir.exist?(d).should be true
    end

    for f in %w{config.yml posts/hedge} do
      File.file?(f).should be true
    end
  end

  it "adds a blog entry" do
    run("jj --config #{@cfgdir} add")
    Dir.glob('posts/*.post').size.should equal 1
  end

  it "edits articles" do
    posts = Dir.glob('posts/*.post')
    posts.size.should equal 1

    before = slurp(posts[0])
    run("jj --config #{@cfgdir} edit 1")
    after = slurp(posts[0])

    before.should_not equal after
    before.size.should be < after.size
  end

  it "displays article IDs" do
    results = run("jj list --full").split
    id = results[1]
    File.file?("posts/#{id}.post").should be true
  end

  it "lets you publish or unpublish posts" do
    id = run("jj list --full").split()[1]
    path = "rendered/#{id}"

    run("jj render -a")
    Dir.exist?(path).should be false

    run("jj publish 1 y")
    run("jj render -a")
    Dir.exist?(path).should be true

    run("jj publish 1 n")
    run("jj render -a")
    Dir.exist?(path).should be false

    run("jj publish 1 y")
  end

  it "allows attachments and bundles them with the post." do
    id = run("jj list --full").split()[1]

    run("jj attach 1 #{@pwd}/README.md")
    run("jj render -a")

    File.file?("rendered/#{id}/README.md").should be true
    FileUtils.cmp("rendered/#{id}/README.md", "#{@pwd}/README.md").
      should be true
  end

end
