require "rubygems"
require 'json'
require "project"
require "service"
require "color"
require "open-uri"
require "uri"
require "gettext"
require "muxie_maker"

class Cli < MuxieMaker

  include GetText
  bindtextdomain "muxie-maker"

  def initialize
    super()
  end

  def init package, project_name

    unless validate_package(package)
      error _("package must match this pattern <name>.<organization>.<sufix>\n" +
          "or similar, as long as the package contains 3 words separated by dot.")
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
      error _("The %s does not contains the %s file.\n" +
        "Try execute 'muxie-maker init'") % [@project_dir, MUXIE_JSON]
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
      error _("The %s does not contains the %s file.\n" +
        "Try execute 'muxie-maker init'") % [@project_dir, MUXIE_JSON]
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

    unless project_dir?
      error _("The %s does not contains the %s file.\n" +
        "Try execute 'muxie-maker init'") % [@project_dir, MUXIE_JSON]
      return
    end

    # TODO: verificar presença de java 6
    # TODO: verificar presença do android sdk

    unless File.directory? "#{@project_dir}/#{MUXIE_DIR}"
      error _("Project diretory %s not found.\n" +
        "You need to download the project from " +
        "https://github.com/mad3linux/mad3-muxie/tags") % "#{@project_dir}/#{MUXIE_DIR}"
      return
    end

    project = load_project
    update_services(project.services)
    update_package(project.package)
    update_project_name(project.name)

    # http://developer.android.com/tools/building/building-cmdline.html

    # execute ant
    info _("generating apk file...")
    `cd #{@project_dir}/#{MUXIE_DIR} && ant debug -d -v`

    app = @project_dir.split("/").last

    # TODO: criar forma de não usar target dinamico.
    info _("updating project settings...")
    # update project
    `#{@android} update project --target 1 --name #{app} --path #{@project_dir}/#{MUXIE_DIR}`

    
    info _("installing the apk in the emulator...")
    # update project files
    `#{@adb} install -r -l #{@project_dir}/#{MUXIE_DIR}/bin/#{app}-debug.apk`
    
  end

  def clean

    # TODO: criar metodo de validação de arquivos do projeto.
    unless project_dir?
      error _("The %s does not contains the %s file.\n" +
        "Try execute 'muxie-maker init'") % [@project_dir, MUXIE_JSON]
      return
    end

    unless File.directory? "#{@project_dir}/#{MUXIE_DIR}"
      error _("Project diretory %s not found.\n" +
        "You need to download the project from " +
        "https://github.com/mad3linux/mad3-muxie/tags") % "#{@project_dir}/#{MUXIE_DIR}"
      return
    end

    project = load_project

    info _("uninstalling the app...")
    `#{@adb} uninstall #{project.package}`
    info _("cleaning %s...") % "#{@project_dir}/#{MUXIE_DIR}"
    `cd #{@project_dir}/#{MUXIE_DIR} && ant clean`
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

  test - run your app in the emulator.

  export [debug|release] - create the apk file.

  clean - clean the binary files.

  help - show this help.

""")
  end

  private

  def get_uid type
    case type
    when Service::Type::Blogger, Service::Type::Wordpress
      hint _("Your uid is your url. Ex.: www.mad3linux.org")
      return STDIN.gets.chop
    when Service::Type::Twitter, Service::Type::Identica
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
    return package =~ /[a-z]{1}[a-z0-9]+\.[a-z]{1}[a-z0-9]+\.[a-z]{1}[a-z0-9]+/
  end

end
