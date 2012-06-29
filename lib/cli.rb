require 'json'
require "project"
require "service"
require "open-uri"
require "uri"

class Cli

  EMPTY_DIR = 2 # . and .. are listed in #Dir.entries
  MUXIE_JSON = "muxie.json"

  #attr_accessor :command, :args, :project_dir

  def initialize command
    @command = command #Deprecated
    @project_dir = Dir.pwd
  end

  def init project_name

    if Dir.entries(@project_dir).size() == EMPTY_DIR

      info "writing #{MUXIE_JSON} file..."
      name = @project_dir.split("/").last
      name = project_name unless project_name.nil?
      project = Project.new(name)

      save project
    else
      error "directory is not empty. Please remove all files first."
    end
    
  end

  def add_service

    unless project_dir?
      error "The #{@project_dir} does not contains the #{MUXIE_JSON} file." +
        "Try execute 'muxie-maker init'"
      return
    end

    service = Service.new
    
    puts "Choose a service:"
    puts Service::Type::to_s
    entry = STDIN.gets.to_i
    service.type = entry if Service::Type::to_a.include? entry
    if entry == 0
      error "option not found. exiting."
      return
    end

    puts "What's you uid?"
    entry = get_uid(service.type)
    if entry == nil or entry.empty?
      error "uid not valid. exiting."
      return
    else
      service.uid = entry
    end

    puts "Describe the service. Ex.: @mad3linux or Linux Blog."
    entry = STDIN.gets.chop
    if entry == nil or entry.empty?
      error "description not valid. exiting."
      return
    else
      service.desc = entry
    end

    project = parse_project
    project.add_service(service)
    save project
    info "service added."
  end

  def info msg
    puts "[info] #{msg}"
  end

  def error msg
    puts "[error] #{msg}"
  end

  def hint msg
    puts "[hint] #{msg}"
  end

  private

  def find_facebook_uid pagename
    begin
      response = open("https://graph.facebook.com/#{pagename}").read
      result = JSON.parse response
      info "Your uid is #{result["id"]}."
      return result["id"]
    rescue Exception => ex
      error ex
      return nil
    end
  end

  def get_uid type
    case type
    when Service::Type::Blogger, Service::Type::Wordpress
      hint "Your uid is your url. Ex.: www.mad3linux.org"
      return STDIN.gets.chop
    when Service::Type::Twitter, Service::Type::Identica
      hint "Your uid is your username. Ex.: mad3linux"
      return STDIN.gets.chop
    when Service::Type::Facebook
      hint "Your uid is hidden under your page name."
      pagename = STDIN.gets.chop
      return find_facebook_uid(pagename)
    when Service::Type::Custom
      hint "Your uid is the complete url for your RSS service. " +
        "Ex.: http://www.mad3linux.org/feed"
      url = STDIN.gets.chop
      # check for a valid URL
      unless (url =~ URI::regexp).nil?
        return url
      else
        return nil
      end
    end
  end

  def save project
    File.open("#{@project_dir}/#{MUXIE_JSON}", "w") do |f|
      f.puts project.to_json
    end
  end

  def parse_project
    contents = File.open("#{@project_dir}/#{MUXIE_JSON}").read
    json = JSON.parse contents
    project = Project.new(json["name"])
    project.icon_color = json["icon_color"]
    json["services"].each do |service|
      project.add_service(service)
    end
    return project
  end

  def project_dir?
    File.exists? "#{@project_dir}/#{MUXIE_JSON}"
  end

end
