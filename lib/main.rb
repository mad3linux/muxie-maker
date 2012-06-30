#!/usr/bin/env ruby

$:.unshift File.expand_path('../../lib', __FILE__)

require "cli"
require "rubygems"
require "gettext"

include GetText
bindtextdomain "muxie-maker"

#################
# main
#################
if __FILE__ == $0

  if ARGV.size() == 0
    # TODO: create a gui
    puts _("initializing gui...")
  else
    command = ARGV[0]
    # create a command line object
    cli = Cli.new
    
    case command
    when "init"
      cli.init ARGV[1]
    when "service"
      cli.add_service
    when "color"
      cli.color
    when "test"
      cli.test
    when "export"
      puts "on development"
    when "clean"
      cli.clean
    when "help"
      cli.help
    else
      cli.help
    end
  end

end