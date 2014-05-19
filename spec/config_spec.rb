
require 'spec_helper'

describe BlogConfig do
  before :each do
    @cfg = BlogConfig.new()
  end

  it "lets you set and read values." do
    @cfg.keys.size.should_not be_zero

    # string field
    @cfg[:title].should eql ""
    @cfg[:title] = "foo"
    @cfg[:title].should eql "foo"

    # num field
    @cfg[:pagesize].should eql 0
    @cfg[:pagesize] = 5
    @cfg[:pagesize].should eql 5

    # bool field
    @cfg[:quotes] = true
    @cfg[:quotes].should be true
    @cfg[:quotes] = false
    @cfg[:quotes].should be false
  end

  it "enforces field types." do
    expect{@cfg[:title] = 5}.to raise_error IIError
    expect{@cfg[:title] = nil}.to raise_error IIError
    expect{@cfg[:pagesize] = "5"}.to raise_error IIError
    expect{@cfg[:quotes] = 0}.to raise_error IIError
  end

  it "enforces field names." do
    expect{@cfg[:unused] = 42}.to raise_error IIError
  end

  it "Fails if you set an illegal value." do
    expect {@cfg[:foo] = "x"}.to raise_error IIError
  end

  it "Saves and loads its contents to disk." do
    path = "spec/cfg.tmp"
    @cfg[:title] = "klomp"
    @cfg.save(path)

    @newcfg = BlogConfig.new
    @newcfg.load!(path)
    @newcfg[:title].should eql @cfg[:title]

    File.unlink(path)
  end
end


describe GlobalConfig do
  before :each do
    @cfg = GlobalConfig.new()
  end

  # We assume the host machine has tar and git installed, which is
  # sort of crappy, but you need them to run jj so I'm just going to
  # require it for the test.
  it "locates git" do
    @cfg.load!("./bogus/dir/and/file")  # forces guessing

    @cfg[:git].should_not eql ""
    File.executable?(@cfg[:git]).should eql true
  end

end
