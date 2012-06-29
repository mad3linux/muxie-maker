#!/usr/bin/env ruby
#
# 		muxie-maker
#
#       Copyright 2012 Átila Camurça <camurca.home@gmail.com>
#
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 2 of the License, or
#       (at your option) any later version.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#       MA 02110-1301, USA.
#

$:.unshift File.expand_path('../../lib', __FILE__)

require "cli"

# main
if __FILE__ == $0

  if ARGV.size() == 0
    # TODO: create a gui
    puts "initializing gui..."
  else
    # create a command line object
    command = ARGV[0]
    cli = Cli.new command
    
    case command
    when "init"
      cli.init ARGV[1]
    when "service"
      cli.add_service
    end
  end

end