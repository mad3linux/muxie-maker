require "rubygems"
require 'json'
require "project"
require "service"
require "color"
require "open-uri"
require "uri"
require "gettext"
require "muxie_maker"
require 'webrick'
require 'erb'
require "assets/muxie_servlet"

class Cli < MuxieMaker

  include GetText
  bindtextdomain "muxie-maker"
  
  include WEBrick

  def initialize
    super()
  end

  def init package, project_name

    unless validate_package(package)
      return
    end

    if Dir.entries(@project_dir).size() == EMPTY_DIR

      info _("writing %s file...") % MUXIE_JSON
      name = @project_dir.split("/").last
      name = project_name unless project_name.nil?
      project = Project.new(package, name)

      save project
    else
      error _("directory is not empty. Please remove all files first.")
    end
    
  end

  def add_service

    unless project_dir?
      return
    end

    service = Service.new
    
    puts _("Choose a service:")
    puts Service::Type::to_s
    entry = STDIN.gets.to_i
    service.type = entry if Service::Type::to_a.include? entry
    if entry == 0
      error _("option not found. exiting.")
      return
    end

    puts _("What's you uid?")
    entry = get_uid(service.type)
    if entry == nil or entry.empty?
      error _("uid not valid. exiting.")
      return
    else
      service.uid = entry
    end

    puts _("Describe the service. Ex.: @mad3linux or Linux Blog.")
    entry = STDIN.gets.chop
    if entry == nil or entry.empty?
      error _("description not valid. exiting.")
      return
    else
      service.desc = entry
    end

    project = load_project
    project.add_service(service)
    save project
    info _("service added.")
  end

  def color

    unless project_dir?
      return
    end

    puts _("Choose from the options:")
    # TRANSLATORS: try to keep the items aligned
    puts _("[1] green   [2] blue   [3] orange\n" +
           "[4] red     [5] purple")
    entry = STDIN.gets.to_i
    if entry > 0
      project = load_project
      case entry
      when 1:
          project.icon_color = Color::GREEN
      when 2:
          project.icon_color = Color::BLUE
      when 3:
          project.icon_color = Color::ORANGE
      when 4:
          project.icon_color = Color::RED
      when 5:
          project.icon_color = Color::PURPLE
      else
        error _("option not found. exiting.")
        return
      end
      save project
      info _("icon color changed.")
    else
      error _("option not found. exiting.")
    end
  end

  def test
    generate_apk
  end

  def release
    mode = "release-unsigned"
    mode = "release" if File.exists? "#{@project_dir}/#{MUXIE_DIR}/ant.properties"
    generate_apk(mode)
  end

  def clean all=false

    unless project_dir? and has_muxie_dir? and validate_installed_tools?
      return
    end

    project = load_project
    adb_uninstall(project.package) if all
    
    ant_clean
  end

  def export
    # TODO: support for apk versions
    export_apk
  end

  def genkey
    # required
    if @keytool.empty?
      error _("keytool not found. keytool is part of the Java Platform\n" +
        "You will need keytool just to sign your application.\n")
      return
    end

    # generate a new keystore
    hint _("follow the instructions to create a new keystore.")
    project = load_project
    `#{@keytool} -genkey -v -keystore #{@project_dir}/#{MUXIE_KEYSTORE} -alias #{project.package} -keyalg RSA -keysize 2048 -validity 10000`

    File.open("#{@project_dir}/#{MUXIE_DIR}/ant.properties", "w") do |f|
      f.puts "key.store=#{@project_dir}/#{MUXIE_KEYSTORE}"
      f.puts "key.alias=#{project.package}"
    end
  end

  def help
    # TRANSLATORS: make sure to do not translate the commands, only the description.
    puts _("""
SYNOPSIS
  muxie-maker command [options]

COMMANDS
  init package [name] - initialize a new project.
    the 'package' must be something like name.organization.app or org.website.app

  service - add a new service to the project.

  color - change the color of the icon (default:GREEN).

  test - create the apk in debug mode and run your app in the emulator.

  release - create the apk in release mode and run your app in the emulator.

  export - copy the apk files to the project directory.

  clean - clean the binary files under mad3-muxie/bin/ directory.

  help - show this help.

""")
  end

  def server
    unless project_dir?
      return
    end

    s = HTTPServer.new( :Port => 9669, :DocumentRoot => File.dirname(__FILE__) + "/assets" )
    s.mount("/muxie-maker", MuxieServlet)
    trap("INT"){
      s.shutdown
    }
    info _("access http://localhost:9669/muxie-maker")
    s.start
  end

  private

  def get_uid type
    case type
    when Service::Type::Blogger, Service::Type::Wordpress
      hint _("Your uid is your url. Ex.: www.mad3linux.org")
      return STDIN.gets.chop
    when Service::Type::Twitter
      hint _("Your uid is your username. Ex.: mad3linux")
      return STDIN.gets.chop
    when Service::Type::Facebook
      hint _("Your uid is hidden under your page name. Let me search for you")
      pagename = STDIN.gets.chop
      uid = (pagename.to_i > 0 ? pagename : nil)
      if uid.nil?
        info _("searching for your uid...")
        uid = find_facebook_uid(pagename)
      else
        info _("I see that you already know your uid. Well done!")
      end
      info _("Your uid is %d.") % uid
      return uid
    when Service::Type::Identica
      # TRANSLATORS: look at the identica profile page to see how they translate 'User ID'.
      hint _("Your uid is in your identica profile page. Look for 'User ID'")
      return STDIN.gets.chop
    when Service::Type::Custom
      hint _("Your uid is the complete url for your RSS service. " +
        "Ex.: http://www.mad3linux.org/feed")
      url = STDIN.gets.chop
      # check for a valid URL
      unless (url =~ URI::regexp).nil?
        return url
      else
        return nil
      end
    end
  end

  def validate_package package
    unless package =~ /[a-z]{1}[a-z0-9]+\.[a-z]{1}[a-z0-9]+\.[a-z]{1}[a-z0-9]+/
      error _("package must match this pattern <name>.<organization>.<sufix>\n" +
          "or similar, as long as the package contains 3 words separated by dot.")
      return false
    end
    return true
  end

  def generate_apk mode="debug"

    unless project_dir? and has_muxie_dir? and validate_installed_tools?
      return
    end

    project = load_project
    update_services(project.services)
    update_package(project.package)
    update_project_name(project.name)
    change_color(project.icon_color)
    
    # http://developer.android.com/tools/building/building-cmdline.html

    app = @project_dir.split("/").last
    android_update_project(app)

    case mode
    when "debug"
      ant_debug
    when "release-unsigned", "release"
      ant_release
    end

    adb_install(app, mode)
  end

end
