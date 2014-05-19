#!/bin/sh
exec ruby -x "$0" "$@"
#!ruby

filename = ARGV[0]

data = File.open(filename, "r") {|fh| fh.lines.to_a}
data = data.map {|line| line =~ /^Subject:/ and line = "Subject: new post\n"; line}

data += ["\n", "Post text goes here.\n"]

File.open(filename, "w") {|fh| fh.write(data.join(""))}





