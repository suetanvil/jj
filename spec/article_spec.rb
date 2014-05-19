
require 'spec_helper'

Article.class_init()

# We override time_now_gmtime() to increase by at least on second
# between calls.  This saves time during testing.
class Article
  @@__t = 0
  def self.time_now_gmtime
    @@__t += 1
    return Time.now.gmtime + @@__t
  end
end

describe Article do
  before :each do
    @ar = Article.new

    @ar.subject = "subject"
    @ar.contents = "contents"
  end

  it "holds text" do
    @ar.subject.should eql "subject"
    @ar.contents.should eql "contents"
  end

  it "replaces newlines and tabs in the subject" do
    @ar.subject = "foo\nbar\tquux"
    @ar.subject.should match(/\A(\S| )*\z/)
  end

  it "maintains its modification time" do
    @ar.date.should be < Article.time_now_gmtime
  end

  it "maintains its creation time as distinct and fixed" do
    @ar = Article.new()
    t = @ar.creationDate
    t.should eql @ar.date

    @ar.contents = "new contents to update timestamp"
    t.should eql @ar.creationDate
    t.should be < @ar.date
  end

  it "updates its timestamp when modified" do
    t1 = @ar.date

    @ar.subject = "new subject"
    @ar.date.should be > t1
    t2 = @ar.date

    @ar.contents = "new content"
    @ar.date.should be > t2
  end

  it "doesn't change the timestamp unless the content actually changes" do
    t1 = @ar.date

    @ar.contents = @ar.contents
    @ar.date.should eql t1

    @ar.subject = @ar.subject
    @ar.date.should eql t1
  end

  it "preserves published status" do
    @ar.publish.should eql false
    @ar.publish = true
    @ar.publish.should eql true
  end

  it "tracks first publication time" do
    @ar.publishDate.should eql nil

    @ar.publish = true
    pd = @ar.publishDate
    
    @ar.publishDate.should eql pd
    pd.should be <= Article.time_now_gmtime()

    @ar.publish = false
    @ar.publish.should eql false
    @ar.publish = true
    @ar.publishDate.should eql pd
  end

  it "tests for equality" do
    (@ar == @ar).should be true
    (@ar == @ar.clone).should be true
    (@ar == 42).should be false

    t = Article.new
    (@ar == t).should be false
  end

  it "serializes and deserializes" do
    @ar.subject = "serialization test"
    @ar.contents = "This is the contents."

    t = Article.new.restore!(@ar.storable)
    @ar.should eql t

    @ar.publish = true
    t = Article.new.restore!(@ar.storable)
    @ar.should eql t
  end

  it "preserves the text of malformed articles" do
    @ar.malformed.should be false

    mangled = <<EOF
Date: march 12
Subject: blort

text text text

EOF
    @ar.restore!(mangled)

    @ar.malformed.should be true
    @ar.subject.should match(/\*MALFORMED\*/)
    @ar.contents.should eql mangled
    @ar.publish.should be false
  end

  it "renders its contents to html" do
    @ar.contents = "these are *contents*."
    @ar.contents_rendered.should match(/\<em\>/)
  end

  it "renders its title to html (but filters user html)" do
    @ar.subject = "*hello* <b>world</b>"
    @ar.subject_rendered.should match(/\<em\>hello\<\/em\>/)
    @ar.subject_rendered.should_not match(/\<b\>world/)
  end

  it "provides a sanitized version of the subject line" do
    @ar.subject = "foo*bar.quux/bobo\\zazzle-+=,xx"
    @ar.subject_sanitized.should_not match(/[^-a-zA-Z0-9_]/)
  end
  
end

