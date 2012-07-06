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

  # TODO: create a gui

  command = ARGV[0]
  # create a command line object
  cli = Cli.new
  begin
    case command
    when "init"
      cli.init ARGV[1], ARGV[2]
    when "service"
      cli.add_service
    when "color"
      cli.info _("this option is still in development.")
      cli.color
    when "test"
      cli.test
    when "export"
      cli.export
    when "genkey"
      cli.genkey
    when "clean"
      cli.clean
    when "clean-all"
      cli.clean true
    when "release"
      cli.release
    when "help"
      cli.help
    else
      cli.error _("option not found. Try one of the options below.")
      cli.help
    end
  rescue SystemExit, Interrupt
    cli.error _("\nCtrl-c captured. Exiting now.")
    raise
  rescue Exception => ex
    # cli.error ex
  end
  

end