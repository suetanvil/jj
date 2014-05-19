
require 'open3'

require 'util'

class Git
  def initialize(path, showOutput)
    @gitpath = path
    @showOutput = showOutput
  end

  def init
    git('init')
  end

  def add(*args)
    git('add', *args)
  end

  def commit(message)
    git('commit', '-m', message)
  end

  def push
    git('push')
  end

  def pull
    git('pull')
  end

  def clone(url, dest)
    git('clone', url, dest)
  rescue IIError => e
    raise IIGitFetchError, e.message
  end

  # Run 'git' with arguments.  (This should really be private, but the
  # unit tests like to override it so I've made it public to properly
  # annotate how it's used.)
  def git(*args)
    stdout, stderr, status = run(@gitpath, *args)
    puts "$ #{@gitpath} #{args.join(' ')}\n#{output}\n#{stderr}" if @showOutput
    
    raise IIGitFetchError,"Error running git command: #{stderr} " + 
      "'#{@gitpath} #{args.join(' ')}'" unless status.exitstatus == 0

    nil
  end

  private

  # Wrapped for testability
  def exitstatus()   $?.exitstatus; end

  def run(*cmd)
    return iowrap {
      stdout, stderr, status = Open3.capture3(*cmd)
    }
    return [stdout, stderr, status]
  end

end
