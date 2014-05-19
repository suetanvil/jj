
require 'spec_helper'

# Time to wait between filesystem operations before the timestamp will
# show up differently.  Most *nix filesystems have a minimum
# resolution of 1 second or less but if you know your filesystem has a
# higher resolution, you can save time by lowering this.
MTIME_LAG = 1.0
#MTIME_LAG = 0.01

def cleanup(dir)
  FileUtils.rm_rf(dir)
end

describe Storage do
  before :each do
    @root = "storage_test_tmp"
    #cleanup(@root)
    Dir.mkdir(@root)
    Dir.chdir(@root)


    @git = Git.new('not-really-git', false)
    def @git.git(*cmd)
      @count = 0 if @count == nil
      @count += 1
    end

    def @git.count
      @count
    end

    @storage = Storage.new(@git)
    @storage.create
  end

  after :each do
    Dir.chdir("..")
    cleanup(@root)
  end

  it "creates the storage directory if not present" do
    Dir.chdir("..")
    cleanup(@root)
    Dir.mkdir(@root)
    Dir.chdir(@root)
    
    @storage.create

    File.exist?(Storage::POSTDIR).should be true
    File.ftype(Storage::POSTDIR).should eql "directory"
    File.exist?(Storage::CFGFILE).should be true
  end

  it "detects if the current directory is a blog directory." do
    @storage.inBlogDir?.should be false

    Dir.mkdir(".git")  # we've disabled git so we need to fake it here
    @storage.inBlogDir?.should be true

    File.unlink(Storage::CFGFILE)
    @storage.inBlogDir?.should be false
  end

  it "stores and retrieves articles." do
    a = Article.new
    a.subject = "test article."
    a.contents = "test contents."

    Dir.glob(File.join(Storage::POSTDIR, "*.post")).size.should eql 0

    id = @storage.new_article_id
    @storage.put(id, a)
    Dir.glob(File.join(Storage::POSTDIR, "*.post")).size.should eql 1

    a2 = @storage.get(id)
    a2.should eql a
  end

  it "allows replacement of articles" do
    a1 = Article.new

    id = @storage.new_article_id
    @storage.put(id, a1)
    @storage.get(id).should eql a1

    a2 = Article.new
    a2.contents = "new contents"
    a2.should_not eql a1
    
    @storage.put(id, a2)
    @storage.get(id).should eql a2
  end

  it "can list only published articles" do
    (1..5).each{|n| 
      a = Article.new
      a.subject = "article #{n}"
      @storage.put(@storage.new_article_id, a)
    }

    @storage.ids.size.should eql 5
    @storage.published_ids.size.should eql 0

    id1 = @storage.ids[0]
    a = @storage.get(id1)
    a.publish = 1
    @storage.put(id1, a)

    @storage.published_ids.size.should eql 1
    @storage.published_ids[0].should eql id1
  end

  it "commits changes to git" do
    base = @git.count
    @storage.put(@storage.new_article_id, Article.new)
    @git.count.should eql base+2 # git add, git commit
  end

  it "creates a default blog config if not present" do
    cfg = @storage.get_config()
    cfg.class.should eql BlogConfig
    cfg[:pagesize].class.should eql Fixnum
  end

  it "stores and retrieves a config object." do
    base = @git.count

    cfg = @storage.get_config()
    cfg[:title].should_not eql "test title"
    @git.count.should eql base

    cfg[:title] = "test title"
    @storage.set_config(cfg)
    @git.count.should eql base+2

    cfg2 = @storage.get_config()
    cfg2[:title].should eql cfg[:title]
  end

  it "converts between id and filename" do
    id = @storage.new_article_id
    @storage.file2id(@storage.id2file_base(id)).should eql id
    @storage.file2id(@storage.id2file(id)).should eql id
  end

  it "returns timestamp of the config file" do
    now = @storage.mtime_cfgfile
    sleep MTIME_LAG

    cfg = @storage.get_config()
    cfg[:title] = "mooooooo"
    @storage.set_config(cfg)

    later = @storage.mtime_cfgfile

    now.should < later
  end

  it "returns timestamps of posts" do
    id = @storage.new_article_id
    @storage.put(id, Article.new)
    now = @storage.mtime(id)
    now.should_not eql nil

    sleep MTIME_LAG

    @storage.put(id, Article.new)
    later = @storage.mtime(id)
    later.should > now
  end

  it "adds and lists attachments" do
    id = @storage.new_article_id
    @storage.put(id, Article.new)
    @storage.attachments(id).should eql []

    gb = @git.count
    @storage.put_attachments(id, ['../README.md'])
    @git.count.should be > gb

    @storage.attachments(id).size.should eql 1
    a1 = @storage.attachments(id)[0]
    File.basename(@storage.attachments(id)[0]).should eql 'README.md'
    File.file?(a1).should be true
  end

  it "cleans up if adding an attachment fails" do
    id = @storage.new_article_id
    @storage.put(id, Article.new)
    @storage.attachments(id).should eql []

    gb = @git.count

    expect{
      @storage.put_attachments(id, ['../README.md', 'non-existant-file'])
    }.to raise_error IIError
    @git.count.should eql gb

    @storage.attachments(id).size.should eql 0
  end
end
