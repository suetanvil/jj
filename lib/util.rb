

class IIError < Exception; end
class IIUserError < IIError; end
class IIGitFetchError < IIUserError; end
class IIArticleError < IIError; end


#class IIInternalError < Exception; end

# Wrap and rethrow an IO error with an IIError or subclass
def iowrap
  begin
    result = yield()
  rescue IOError,SystemCallError => e
    raise IIError, "IO Error: #{e.message}"
  end
  return result
end

# Print a message and exit.  All arguments printed after being
# stringified and concantenated together with spaces separating them.
def die(*msg)
  puts msg.map{|m| m.to_s}.join(" ")
  exit 1
end

# Read in a file and return its contents as a string.  If
# 'allowMissing' is true, return an empty string if the file does not
# exist.
def slurp(filename, allowMissing = false)
  return '' if allowMissing && !File.exist?(filename)
  return iowrap do 
    File.open(filename, "r") { |fh| fh.each_line.to_a.join("") }
  end
end

# Write the contents of 'text' to file at 'filename', creating or
# overwriting the file.
def unslurp(filename, text)
  iowrap do
    File.open(filename, "w") { |fh| fh.write(text) }
  end
  return nil
end


# Singleton object to handle user messages; usually only used by the
# following functions.
MESSAGE_PRINTER = Class.new() {
  attr_accessor :verbose
  def initialize()
    @verbose = false
  end

  def msg(*args)
    return unless @verbose
    warn(*args)
  end

  def warn(*args)
    puts args.join(" ")
  end
}.new()

def msg(*args)
  MESSAGE_PRINTER.msg(*args)
end

def warn(*args)
  MESSAGE_PRINTER.warn(*args)
end
