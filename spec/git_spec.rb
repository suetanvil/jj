

require 'spec_helper'

describe Git do
  it "invokes various git commands" do
    @git = Git.new('fake-git', false)

    # Mock the syscall
    def @git.git(*args)
      @xxx = (['fake-git'] + args).join(" ")
      nil
    end

    def @git.xxx
      return @xxx
    end

    @git.init
    @git.xxx.should eql "fake-git init"

    @git.add("foo", "bar")
    @git.xxx.should eql "fake-git add foo bar"

    @git.commit("msg")
    @git.xxx.should eql "fake-git commit -m msg"

    @git.push
    @git.xxx.should eql "fake-git push"

    @git.pull
    @git.xxx.should eql "fake-git pull"
  end

  it "throws an exception when given an invalid git path" do
    @git = Git.new('spec/fakebin/bogus-program', false)
    expect {@git.init}.to raise_error IIError;
  end

  it "throws an exception when the program it calls exits false" do
    @git = Git.new('/bin/false', false)
    expect {@git.init}.to raise_error IIError;
  end

  it "invokes an external program" do
    @git = Git.new('/bin/true', false)
    @git.init()
    @git.add("a", "b", "c")
  end

  it "throws a special exception when clone() fails" do
    @git = Git.new('/bin/false', false)
    expect {
      @git.clone("git@github.com:/foo/bar.git", "foo")
    }.to raise_error IIGitFetchError
  end
end
