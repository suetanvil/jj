# jj -- Yet Another git+Markdown static blog generator

`jj` is a blogging tool that manages your static blog for you.  It is
similar in spirit to Jekyll/Octopress.

Your posts are written in
[Markdown](http://daringfireball.net/projects/markdown/); `jj`
converts them to HTML, stuffs them into a template and uploads them to
your website.  It also puts them into [git](http://git-scm.com/) so
that you can manage your changes like a civilized human being.

`jj` uses [Redcarpet](https://github.com/vmg/redcarpet) for rendering
and [Liquid](http://liquidmarkup.org/) for templates (but you don't
need to worry about that if you want to--there are pre-existing
templates available.)

You probably want to have at least a basic understanding of Git,
though.

`jj` stands for "just journal".

## Installation

There's no gem (yet), so you'll need to install from Git:

    git clone https://github.com/suetanvil/jj jj
    bundle install
    ln -s jj/bin/jj /somewhere/in/my/path/

## Blogging

### Creating a Blog and Adding Content

First, create a new blog:

    $ mkdir myblog
    $ cd myblog
    $ jj init

The blog is empty:

    $ jj list
    (nothing)

To add a post:

    $ jj add

This will launch an editor.  We add a subject and single-line body.
The other headers can be edited but should usually be left alone.
    
    Subject: First Post
    Date: 2014-05-17 22:37:04 UTC
    Publish: No
    Creation-Date: 2014-05-17 22:37:04 UTC

    Some **Markdown** text goes here.

(If you have problems, ensure that `jj` can find your editor.  Take a
look at your global config file, `~/.jj/config.yml`.  This is
explained below.)

The post will now show up:

    $ jj list
    1      *First Post

The asterisk ('\*') indicates that the post is still a draft and won't
appear on the website.  To mark it as published:

    $ jj publish 1 y

Now, the asterisk will be gone.

    $ jj list
    1       First Post


### Rendering the Website

You render the website with the `render` subcommand.

    $ jj render -l

(If this doesn't open a browser window, launch your favorite browser
on `rendered/index.html`.)

This is rendered using the default template, which is, uh, lacking.
You can switch to a better one.  Simply edit `config.yml` and change
the `template` field to point to the URL of another theme's git
repository:

    $ vi config.yml

(Right now, there's only one on github:)

    :template: https://github.com/suetanvil/jj-andreas08

and don't forget to commit your changes:

    $ git add config.yml
    $ git commit -m "Updated config."

If you want, you can also use this opportunity to update other
arguments.  See below for the list of fields and what they mean.

Once you've saved, rerender the blog:

    $ jj render

and refresh your browser window.  Your changes should have now taken
effect.  (Note that I've left off the `-l` command, since you
presumably still have a browser window open on the front page.)


### Publishing on the Web

Actually publishing on the web requires a few more steps.

First, edit `config.yml` and set the site's actual URL:

    :base_url: http://www.mysite.com/blog/

Actually uploading the rendered site is done by some external program.
In this example (and in real life), I'm using `rsync`.  Set the
command in `config.yml`:

    :upload_cmd: 'rsync --rsh=ssh -avz --delete --ignore-errors --chmod=Fa+r {{src_dir}}/ me@www.myblog.com/public_html/blog/'

Then, say:

    $ jj upload

This will automatically rerender the blog if necessary.


### Using Git

`jj` automatically creates a git repository when you initialize it and
commits every change to it.  A `git log` will show you this history.

You can branch, clone, set upstreams and so on just like any other git
repository.  New article names are virtually guaranteed to be unique
so it's safe to create new articles on a branch and then merge them to
the trunk.

Editing files directly with an editor (e.g. editing `config.yml`) will
**not** be added to git and must be committed manually.

(Note: unpublished and/or deleted posts are **still in your git
history**.  That means that anyone with access to the blog's git
repository can read those posts.  If you decide to use a public git
hosting service such as GitHub to host your blog's contents, you need
to be aware that your unpublished content is **still being published**
and act accordingly.)


### Adding Images (or Other Attachments)

You can add images (or other data) with the `attach` subcommand:

    $ jj attach 1 ~/wallpaper/b5.jpg

This will copy the image file into the same directory as the text of
the blog post.

Of course, you will need to reference the image from the post itself:

    $ jj edit 1

    ...
    [A picture]($CONTENT_PATH/b5.jpg)
    <img src="$CONTENT_PATH/b5.jpg">
    ...

    $ jj render

The string `$CONTENT_PATH` is automatically replaced by the relative
path to the file.  This is described in more detail below.

Note: Images are are checked into git, with everything that entails.
Replacing or deleting an attachment will not remove the original
version from the repository.


## Global Configuration

The first time `jj` is run, it will create a configuration directory
in your home directory (as defined by the HOME environment variable).
This contains the global configuration file and the template cache.

The global config file is named `config.yml`.  It is a standard
[YAML](http://yaml.org/) file and contains the following settings,
which may be edited as needed:

### `editor`

This is the path to the editor `jj` will use.  This program **must**
not be run in the background.  `jj` expects all editing to be done
when it exits.  It is initially taken from your `VISUAL` environment
variable if present.  If not, `jj` will try to find the path to `vi`.
   
### `git`

This is the path to your `git` command if present in your path.  `jj`
normally sets it to whatever `git` command is in your path.  Edit this
field if that's not correct.

### `browser`

This is the browser to use when displaying a rendered site.  `jj` uses
the `BROWSER` environment variable if set.  Otherwise, it looks for
Firefox or Chrome in your path.



## The Template Cache

`jj` also stores local templates in the subdirectory
`~/.jj/template_cache`.  It is safe to delete this and refetch your
templates (or just do `jj template --clear`).

You can also hunt around there to recover a template you use that has
disappeared from the Internet if you need to.



## Blog Configuration

Each `jj` blog is configured using a [YAML](http://yaml.org/) file
named `config.yml`.

Note that while the file is added to your git repository immediately
after the blog is created, `jj` will not automatically commit your
changes.  You will need to do that by hand.

`config.yml` contains the following configuration values:

### `title`, `subtitle`, `copyright`, `disclaimer`, `author`

These are strings which are displayed at various places on the blog
page.  Their meanings should be self-evident.

### `navbar`

This is the content of the navigation bar, a list of URLs (e.g. an
'about' page, the RSS feed, etc.) displayed on all pages.  The config
field is a single string consisting of label and URL pairs, separated
by '||' symbols.  A single '|' separates a label from its matching
URL:

    'Desc. 1|URL 1||Desc. 2|URL 2||Desc. 3|URL 3|| ...'

The URL parts are actually Liquid templates and receive the same
parameters as `main_template.tpl` (see below).  Here is an example:

    'Home|{{rootpath}}/index.html||My Website|http://me.ca||RSS|{{rss_link}}'

### `rss`

This is the RSS mode.  It may be empty (for none) or one of "rss1.0"
or "rss2.0".  RSS is generated by the Ruby `RSS::Maker` module and so
is subject to its quirks and limitations.


### `no_intra_emphasis`, `quotes`, `footnotes`

These are all boolean (i.e. `true` or `false`) options to RedCarpet,
the Markdown renderer.  All are enabled by default.

`no_intra_emphasis` causes RedCarpet to ignore underscores inside
words.  For example, if it were set to false, the text
`no_intra_emphasis` in regular text would display the `intra` in
italics and hide the underscores.

`quotes` causes RedCarpet to parse quote ('"') characters into `<q>`
tags.

`footnotes` enables PHP-markdown-style footnotes.  This requires a
recent (i.e. 3.1-ish or later) version of RedCarpet to work.

You reference a footnote like this: `[^1]` (where 1 is the footnote
number).  The matching footnote body takes the form: `[^1]: blah blah
blah`.  It must be on a line by itself somewhere in the document.

### `base_url`

`base_url` is the toplevel URL of the blog on the Internet.  While
`jj` tries to make blog links relative so it will be consistent
independent of its location on the web, there are a few places where
an absolute URL is needed.  In those cases, it this parameter is used.

(At the time of this writing, it is only needed in the generated RSS.)

### `upload_cmd`

`upload_cmd` is a string containing the external program and arguments
which `jj` invokes to upload the blog's content to the web server.
`rsync` (as shown above) is a good tool for this but any runnable
program is allowed.

The command is evaluated by your shell and so is subject to whatever
interpretation or substitutions it performs.

If the command contains the text `{{src_dir}}`, that text is replaced
with a path to the rendered website.  Note that while this resembles
Liquid markup, the string is not a Liquid template.

### `pagesize`, `recent_count`, 

These are numeric values affecting the front page.

`pagesize` sets the number of articles that will be displayed on the
blog's front page.  It defaults to 5.

`recent_count` sets the number of article headlines that appear in the
"Recent Posts:" sidebar.  It defaults to 10.


## Hook Templates

Hook templates are a simple mechanism to inject custom HTML into a
blog without altering the template it uses.

If one or more of the following files is present in the blog's
top-level directory at render time, it will be parsed as a Liquid
template and its expanded content will be inserted into the resulting
HTML.

The main intended use of this feature is to enable third-party comment
systems such as Disqus.

### `header_script.tpl`, `body_script.tpl`

These are inserted into every blog page.  The contents of
`header_script.tpl` appears in the `<head>` section while
`body_script.tpl` is inserted into the `<body>` section, usually
toward the end.

Both have all of the parameters of the `main_template.tpl` template
(see below) except, of course, for `hdr_script` and `body_script`.

### `article_script.tpl`

This is inserted into each article, typically toward the bottom after
the text.  It receives all of the parameters of the
`article_template.tpl` (see below) except for `art_script`.


## Other Stuff

### Cached Content

`jj` stores a lot of temporary data locally and while it is pretty
good at keeping things up to date as needed, you may occasionally need
to manually clear things out.

Running `render` with the `-a` flag will force it to re-render
everthing.  Alternately, you can run

    $ jj clean

or

    $ rm -rf rendered

Templates are cached locally inside the `~/.jj` directory in a
subdirectory named `template_cache`.  You can delete it with

    $ jj template --clear

or

    $ rm -rf ~/.jj/template_cache

Templates are git repositories.  If a template isn't present in the
cache at render time, `jj` will download it (via `git clone`).  It
will then use this cached copy from then on.  (The one exception to
this is the template `default`, which is included with `jj`.)

Since the upstream template may occasionally be improved by its
maintainer, it would be nice to update the cached template.  You do
this by saying

    $ git template --freshen

All of this means that you will most likely need to be connected to
the Internet the first time you render a blog and each time you
freshen your templates.


### File Layout

A `jj` blog has the following layout:

    myblog/         -- the root directory
      *.tpl         -- the hook templates
      config.yml    -- the config file
      .git          -- the git directory
      posts/        -- the content directory
        *.post      -- the post text (RFC822-style text)
        hedge       -- just ignore this.  It's only a hedge.
      attachments/  -- the binary attachments (only present if some exist)
        */*         -- directories are named after posts, minus the extension
      rendered/     -- the rendered site.  Not stored in git.

Post filenames are taken from the current time in milliseconds encoded
in base-36.  As such, each one is almost certainly unique.  This name
is used as an article identifier in many places.


### $CONTENT_PATH

$CONTENT_PATH expands to the relative location of the current article.
This dir will also hold any binary attachments.  It is only expanded
if it is inside a `href`, `data` or `src` attribute of a `a`, `link`,
`area`, `object`, `script` or `img` tag.

If you need the literal string $CONTENT_PATH in the path, replace any
character with its URL-encoding (i.e. percent encoding) form.  For
example, `%24CONTENT_PATH` will not be modified.

Note that it is expanded **before** the site templates but after
Markdown is translated to html.  Thus, both Markdown links and inline
HTML will be affected.


## Writing Templates

Templates are git repositories with the following directory layout:

    template-name/              -- the toplevel directory
      .git                      -- the git metadata
      *                         -- variious ignored files
      template/                 -- the template contents
        article_template.tpl    -- the article content template
        recent_template.tpl     -- the recent articles template
        archive_template.tpl    -- the archive list template
        main_template.tpl       -- the common page template
        *                       -- other template files (CSS, images, etc.)

When a blog is rendered, the *.tpl files are expanded into the blog
content.  All other files in the `template/` subdirectory are copied
unmodified to the top-level directory of the rendered site.

All files above `template/` are ignored.  This is a good place for
a README or related files.

Templates use Liquid.  You should be familiar with the
[Liquid template language](https://github.com/Shopify/liquid/wiki/Liquid-for-Designers)
before you start.

The default template included with `jj` may be a convenient starting
point.


### article_template.tpl

`article_template.tpl` is the template used to format the text of an
individual article.  This comprises the contents of an article's page
as well as the text of each article on the front page.

`jj` defines the following parameters for `article_template.tpl`:

#### `subject`, `rich_subject`

These are the article's subject line, verbatim and as rendered through
Markdown.  In general, `subject` seems to be more useful.

#### `modify_date`, `creation_date`, `pub_date`

These are the modification, creation and publication dates of the
article in human-readable form.

#### `id`, `permalink`

These are all strings.  `id` is a unique identifier for the article
(specifically, the basename of the post file) while `permalink` is the
URL of the article's standalone post.

#### `standalone`

This is a boolean value.  It is true if the content being rendered
will be the only article inserted into a page; false if not.

#### `content_path`, `art_script`

`content_path` is the path to the directory containing attached
content (i.e. the expansion of $CONTENT_PATH).  `art_script` is the
expansion of `article_script.tpl`, the article hook template.

#### `contents`

`contents` is the content of the blog post.  This is HTML generated
from the Markdown source.


### `main_template.tpl`

Every blog page is an expansion of this template.  It defines the
following parameters:

#### `title`, `author`, `subtitle`, `copyright`, `disclaimer`

These are all strings taken from the blog's `config.yml` and their intents are
defined above.

##### `links`, `recent_links`

`links` is an array of 2-element arrays where the first item is
descriptive text and the second a URI.  It is created from the
`navbar` config option.

`recent_links` is HTML containing a list of recent articles.  It is
the expansion of `recent_template.tpl`.

##### `rootpath`, `archive_link`, `rss_link`

These are all strings containing relative paths to other parts of the
rendered website.

`rootpath` points to the blog's toplevel directory; it is mostly used
to reference CSS and other formatting elements.

`archive_link` and `rss_link` point to the archive page and RSS feed
respectively.  `rss_link` will be defined even if RSS has been
switched off.

##### `content`

This is the content of the page as HTML.

##### `hdr_script`, `body_script`

These are the expansions of the header and body hook templates.


### `archive_template.tpl`, `recent_template.tpl`

These are templates for lists of articles and so have the same parameters.

`archive_template.tpl` is the template for the archive page, a single
page listing all published articles.  `recent_template.tpl` is the
template for the side bar, a short list of recent articles.

Each template receives only one parameter: `articles`.  This is a list
of structures, on per article, defining the following fields:

* `page_url`        -- the (relative) URL of the article page.
* `subject`         -- The article subject
* `rich_subject`    -- The article subject rendered as Markdown
* `pub_date`        -- The publication date



