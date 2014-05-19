#!/usr/bin/env ruby

# temporary!
$LOAD_PATH.unshift(File.dirname(__FILE__))

# Command-line arg parser.  For now, a mainline routine.

require 'optparse'
require 'subcommand'

require 'blogaction'

def parse_opts
  include Subcommands

  optValues = {
    showgit:            false,
    confdir:            '',

    browser:            false,
    dryrun:             false,
    norender:           false,
    freshenTplCache:    false,
    clearTplCache:      false,
    showRendered:       false,
    renderAll:          false,
    listIds:            false,
  }

  global_options do |opts|
    opts.banner =
      "Usage: jj [options] [subcommand] [options]\n" + 
      "       jj help\n" +
      "       jj [subcommand] --help\n"
    opts.description = "Simple git-based blogging."
    opts.separator ""
    opts.separator "Global options are:"

    opts.on('--show-git', "Show the output of all 'git' commands.") {
      optValues[:showgit] = true
    }

    opts.on('--list-commands', "List all sub-commands.") {
      list_actions()
      exit 0
    }

    opts.on('--verbose', '-v', "Print extra messages.") {
      MESSAGE_PRINTER.verbose = true
    }

    opts.on('--config PATH', "Specify alternate config dir.") { |cfg|
      optValues[:confdir] = cfg
    }
  end

  command :init     do |opts|
    opts.banner = "Usage: jj init"
    opts.description = "create a new jj blog in this directory."
  end

  command :list     do |opts|
    opts.banner = "Usage: jj list"
    opts.description = "list all posts"

    opts.on('--full', "Show everything (esp. article IDs).") {
      optValues[:listIds] = true;
    }
  end

  command :add      do |opts|
    opts.banner = "Usage: jj add"
    opts.description = "create a new post"
  end

  command :edit     do |opts|
    opts.banner = "Usage: jj edit <id>"
    opts.description = "edit an existing post"
  end

  command :attach   do |opts|
    opts.banner = "Usage: jj attach <id> <filename> ..."
    opts.description = "attach a file to a post"
  end

  command :cat      do |opts|
    opts.banner = "Usage: jj cat <id>"
    opts.description = "send a post's contents to stdout"
  end

  command :tac      do |opts|
    opts.banner = "Usage: jj tac <id>"
    opts.description = "read a post from stdin and store it as article <id>"
  end

  command :publish  do |opts|
    # todo: make the y/n flag an option.
    opts.banner = "Usage: jj publish <id> y/n"
    opts.description = "publish or unpublish the post at <id>"
  end
  
  command :render   do |opts|
    opts.banner = "Usage: jj render [options]"
    opts.description = "render the contents to html"

    opts.on('-l', '--launch-browser', "launch a browser on the site.") {
      optValues[:browser] = true
    }

    opts.on('-s','--show',"print a list of updated articles.") {
      optValues[:showRendered] = true
    }

    opts.on('-a','--all',"re-render the entire site.") {
      optValues[:renderAll] = true
    }
  end

  command :clean   do |opts|
    opts.banner = "Usage: jj clean"
    opts.description = "delete local generated files (e.g. the rendered site)"
  end
  
  command :upload   do |opts|
    opts.banner = "Usage: jj upload [options]"
    opts.description = "Upload the rendered site to a web server"

    opts.on('--dry-run', "do not actually upload the content.") {
      optValues[:dryrun] = true
    }

    opts.on('--no-render', "do not (re)render content before uploading.") {
      optValues[:norender] = true
    }
  end

  command :template do |opts|
    opts.banner = "Usage: jj template --clear|--freshen"
    opts.description = "Clear or update the template cache"

    opts.on('--freshen', "update the template cache.") {
      optValues[:freshenTplCache] = true
    }

    opts.on('--clear', "clear the template cache.") {
      optValues[:clearTplCache] = true
    }
  end

  begin
    cmd = opt_parse()
  rescue OptionParser::InvalidOption => e
    die "#{e.message}.  Try '--help' for a list of valid options."
  end
  return [cmd, optValues]
end




def go
  blog = BlogAction.new()
  optValues = {}    # set by parse_opts

  cmds = {
    'init'      => proc{blog.init},
    'add'       => proc{blog.edit -1},
    'edit'      => proc{|index|
      index = index.to_i
      index > 0 or raise IIUserError,"Missing or invalid article index."
      
      blog.edit index
    },

    'list'      => proc{
      blog.list {|index, publish, subject, idstring|
        ids = optValues[:listIds] ? " #{idstring}" : ""
        printf("%-6d%s %s%.70s\n", index, ids, publish ? ' ' : '*', subject)
      }
    },


    'attach'    => proc{|index, *files|
      index = index.to_i
      index > 0 or raise IIUserError,"Missing or invalid article index."

      blog.attach index, files
    },

    'publish'   => proc{|index, yn|
      index = index.to_i
      yn = yn[0].downcase

      (yn == 'y' || yn == 'n') && index > 0 or
        raise IIUserError, "Usage: publish <index> (y|n)"

      blog.publish(index, yn == 'y')
    },

    'render'    => proc{
      blog.clean() if optValues[:renderAll]
      blog.render(optValues[:browser], optValues[:showRendered])
    },
    
    'clean'     => proc{blog.clean()},

    'cat'       => proc{|index|
      index = index.to_i
      index > 0 or raise IIUserError, "Missing or invalid article index."

      print blog.articleGet(index)
    },

    'tac'       => proc{|index|
      index = index.to_i
      
      index > 0 or raise IIUserError, "Missing or invalid article index."
      
      msg "Waiting for article text on stdin"
      blog.articlePut(index, STDIN.read)
    },

    'upload'    => proc{blog.upload(optValues[:dryrun], optValues[:norender])},

    'template'  => proc{
      die "You must specify either --freshen or --clear." unless
        optValues[:freshenTplCache] || optValues[:clearTplCache]

      die "Specified both --freshen and --clear." if
        optValues[:freshenTplCache] && optValues[:clearTplCache]

      if optValues[:freshenTplCache]
        msg "Freshening templates."
        msgs = blog.freshenTemplates()
        puts "Git errors:\n\n#{msgs.join("\n\n")}" if msgs.size > 0
      elsif optValues[:clearTplCache]
        msg "Clearing template cache."
        blog.clearTemplates()
      end
    },
  }

  cmd, optValues = parse_opts
  msg("Verbose mode enabled.")  # Does nothing unless -v was given.

  action = cmds[cmd]
  die "Invalid command; try 'help' for a list." unless action

  # Fail if arg. counts don't match.  (Recall that negative arity is
  # -max_args - 1; we expect at least one entry in the final arg
  # list.)
  if action.arity != ARGV.size
    expected = action.arity.abs
    
    if action.arity > 0 || ARGV.size < expected
      al = action.arity < 0 ? "at least " : ""
      die "jj #{cmd}: expecting #{al}#{expected} arguments. Got #{ARGV.size}."
    end
  end

  begin
    blog.setup(cmd == 'init', optValues[:showgit], optValues[:confdir])

    cmds[cmd].call(*ARGV)

    blog.teardown()
  rescue IIError => e
    die "Error:", e.message
  end

  exit 0
end



