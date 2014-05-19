
require 'redcarpet'

class Article
  attr_reader :subject, :date, :creationDate, :publish, :publishDate
  attr_reader :malformed, :contents

  def initialize(storedForm = nil)
    @subject = ""
    @date = time_now_gmtime()
    @creationDate = @date
    @publishDate = nil
    @publish = false
    @malformed = false

    @contents = ""

    self.restore!(storedForm) if storedForm
  end

  def self.class_init(opts = {})
    # Render for article bodies.
    @@contents_renderer = Redcarpet::Markdown.
      new(Redcarpet::Render::HTML.new(:prettify => false),
          :no_intra_emphasis => opts[:no_intra_emphasis]    || false,
          :tables => true,
          :strikethrough => true,
          :superscript => true,
          :hilight => true,
          :quote => opts[:quotes]                           || false,
          :footnotes => opts[:footnotes]                    || false,
          )

    # Renderer for article titles.  Filters out HTML and disables
    # multi-line features.
    @@subject_renderer = Redcarpet::Markdown.
      new(Redcarpet::Render::HTML.new(:filter_html => true),
          :no_intra_emphasis => opts[:no_intra_emphasis]    || false,
          :tables => false,
          :strikethrough => true,
          :superscript => true,
          :hilight => true,
          :quote => opts[:quotes]                           || false,
          :footnotes => false,
          )
  end

  def eql?(other)
    return other.class == self.class && state == other.state
  end

  def ==(other)
    return eql?(other)
  end

  # Set @publish and also set @publishDate if this is the first time
  # @publish is set to true.
  def publish=(doit)
    return if doit == @publish
    @publishDate = time_now_gmtime() if doit && @publishDate == nil
    @publish = doit
  end

  # Set subject, ensuring first that it contains no newlines.  Also
  # expands tabs as 4 spaces.
  def subject=(text)
    return if @subject == text
    @subject = text.gsub(/\t/, '    ').gsub(/\s/, ' ')
    timestamp()
  end

  def contents=(text)
    return if @contents == text
    @contents = text
    timestamp()
  end

  # Set the date field to the current time.
  def timestamp
    @date = time_now_gmtime()
  end

  def storable
    return headerBlock() + "\n\n" + @contents
  end
  
  def restore!(stored)
    (header, body) = parseStorable(stored)
    
    @subject = header["Subject"]
    @date = header["Date"]
    @publish = header["Publish"]
    @publishDate = header["Publish-Date"]
    @creationDate = header["Creation-Date"]

    @contents = body

    return self

  rescue IIArticleError => e
    @malformed = true
    @publish = false
    self.subject = "*MALFORMED* " + e.message    # trigger text laundring
    @contents = stored

    return self
  end

  def contents_rendered
    return @@contents_renderer.render(self.contents)
  end

  def subject_rendered
    return @@subject_renderer.render(self.subject)
  end

  def subject_sanitized
    s = subject.gsub(/[^-a-zA-Z0-9_]/, '_')
    return s[0..127]
  end

  private

  def self.headerList
    return [ ["Subject",        :subject],
             ["Date",           :date],
             ["Publish",        :publish],
             ["Publish-Date",   :publishDate],
             ["Creation-Date", :creationDate]]
  end

  # Return a hash mapping downcased headers to their canonical forms
  def self.headerDict
    result = {}
    headerList.each{|k, s| result[k.downcase] = k}
    return result
  end

  # Given a header tag, return the canonical name
  def hdr(wanted)
    self.class.headerList.each{|hdr, tag| return hdr if wanted == tag}
  end

  # Parse the article body and return a dictionary of header values
  # and the article body as two separate values.
  def parseStorable(stored)
    input = StringIO.new(stored)

    headers = parseHeaders(input)
    parseHeaderFields(headers)
    
    body = input.lines.to_a.join("")

    return [headers, body]
  end

  # Parse the text of the header fields into Ruby types.  Also ensure
  # that they all have sane values.
  def parseHeaderFields(headers)

    # Ensure expected fields are present
    for f in [:subject, :date, :publish, :creationDate]
      headers[hdr(f)] ||= ""
    end

    # Parse non-textual values
    headers[hdr(:publish)] = (headers[hdr(:publish)].downcase == 'yes')
    headers[hdr(:date)] = parsedate(headers[hdr(:date)])
    headers[hdr(:creationDate)] = parsedate(headers[hdr(:creationDate)])
    headers[hdr(:publishDate)] = parsedate(headers[hdr(:publishDate)]) if
      headers.has_key?(hdr(:publishDate))

    # Check for missing publish date
    raise(IIArticleError,
          "Malformed article: published with no publication date.") if
      headers[hdr(:publish)] && !headers.has_key?(hdr(:publishDate))
  end

  def parseHeaders(input)
    hdrNames = self.class.headerDict

    result = {}

    while true
      raise IIArticleError, "Malformed input file: no end of headers" if
        input.eof

      line = input.readline
      line.chomp!

      break if line == ""

      matchobj = line.match(/\A([-a-zA-Z0-9_]+)\:(.*)/) or
        raise IIArticleError, "Malformed header line: #{line}"
      hdr, value = matchobj[1], matchobj[2]

      key = hdrNames[hdr.downcase]
      raise IIArticleError, "Unknown header: #{hdr}" unless key

      value.strip!

      result[key] = value
    end

    return result
  end
  
  def headerBlock
    return Article.headerList.
      select{|h,m| m != :publishDate || @publishDate != nil}.
      map{|h,m| "#{h}: #{self.send(m.to_s + 'Hdr')}"}.
      join("\n")
  end

  def subjectHdr()      subject;                    end
  def dateHdr()         fmtdate(date);              end
  def publishHdr()      @publish ? "Yes" : "No";    end
  def publishDateHdr()  fmtdate(publishDate);       end
  def creationDateHdr() fmtdate(creationDate);      end

  def fmtdate(date)
    return date.strftime("%Y-%m-%d %H:%M:%S %Z")
  end

  def parsedate(datestr)
    err = "Malformed date: #{datestr}"

    fields = datestr.gsub(/[-:\/]/, ' ').split(/\s+/)
    raise IIArticleError, err unless fields.size == 7 || fields[-1] != 'UTC'
    fields.pop

    raise IIArticleError, err unless
      fields.select{|f| f.match(/^\d+$/)}.size == fields.size
    fields = fields.map{|f| f.to_i}

    begin
      time = Time.utc(*fields)
    rescue ArgumentError => e
      raise IIArticleError, "Date parse error: #{e.message}"
    end
  end

  # Return the current time.  We use this instead of Time.now.gmtime
  # because saving/restoring loses precision we don't care about,
  # resulting in a restored article not being equal to the original.
  def time_now_gmtime
    return parsedate(fmtdate(self.class.time_now_gmtime()))
  end

  # Wrapper around Time.now.gmtime; this is here so that tests can
  # override the behaviour and advance time faster than normal.
  def self.time_now_gmtime
    return Time.now.gmtime
  end

  protected

  def state
    return [@subject, @date, @publish, @publishDate, @creationDate, @contents]
  end

end
