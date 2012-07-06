require "open-uri"
require "rexml/document"
require 'open3'
require "fileutils"

class MuxieMaker

  include REXML

  EMPTY_DIR = 2 # ./ and ../ are listed in #Dir.entries
  MUXIE_JSON = "muxie.json"
  MUXIE_DIR = "mad3-muxie"
  MUXIE_KEYSTORE = "muxie.keystore"

  def initialize
    @project_dir = Dir.pwd
    @android = `which android`.chop
    @adb = `which adb`.chop
    @keytool = `which keytool`.chop
    @manifest = "#{@project_dir}/#{MUXIE_DIR}/AndroidManifest.xml"
    @strings = "#{@project_dir}/#{MUXIE_DIR}/res/values/strings.xml"
    @sql = "#{@project_dir}/#{MUXIE_DIR}/res/values/sql.xml"
  end

  private

  def find_facebook_uid pagename
    begin
      response = open("https://graph.facebook.com/#{pagename}").read
      result = JSON.parse response
      return result["id"]
    rescue Exception => ex
      error ex
      return nil
    end
  end

  def save project
    File.open("#{@project_dir}/#{MUXIE_JSON}", "w") do |f|
      f.puts project.to_json
    end
  end

  def load_project
    contents = File.open("#{@project_dir}/#{MUXIE_JSON}").read
    json = JSON.parse contents
    project = Project.new(json["package"], json["name"])
    project.icon_color = json["icon_color"]
    json["services"].each do |service|
      project.add_service(service)
    end
    return project
  end

  def project_dir?
    unless File.exists? "#{@project_dir}/#{MUXIE_JSON}"
      error _("The %s does not contains the %s file.\n" +
        "Try to execute 'muxie-maker init'") % [@project_dir, MUXIE_JSON]
      return false
    end
    return true
  end

  def has_muxie_dir?
    unless File.directory? "#{@project_dir}/#{MUXIE_DIR}"
      error _("Project diretory %s not found.\n" +
          "You need to download the project from " +
          "https://github.com/mad3linux/mad3-muxie/tags") % "#{@project_dir}/#{MUXIE_DIR}"
      return false
    end
    return true
  end

  def update_package package
    
    doc = Document.new(File.new @manifest)
    old_package = doc.root.attributes["package"]
    if old_package != package

      doc.root.attributes["package"] = package
      # make a backup of the manifest file
      File.rename @manifest, "#{@manifest}~"

      File.open(@manifest, "w") do |f|
        f.puts doc.to_s
      end

      update_package_in_files(old_package, package)
    end
  end

  def update_package_in_files old_package, package
    file_array = [
      "fidias/model/Helper.java",
      "fidias/view/SimpleActivity.java",
      "mad3/muxie/app/MadActivity.java",
      "mad3/muxie/view/FavoritesActivity.java",
      "mad3/muxie/view/PostListActivity.java",
      "mad3/muxie/view/WebViewActivity.java"
    ]
    info _("updating %d files...") % file_array.size

    file_array.each do |filename|
      complete_path = "#{@project_dir}/#{MUXIE_DIR}/src/#{filename}"
      text = File.read complete_path
      replace = text.gsub /(import #{old_package}.R;)/, "import #{package}.R;"
      File.open(complete_path, "w") {|file| file.puts replace}
    end
  end

  def update_project_name name
    doc = Document.new(File.new @strings)
    #puts doc.root.elements["string[@name='app_name']"].text
    if doc.root.elements["string[@name='app_name']"].text != name
      doc.root.elements["string[@name='app_name']"].text = name
      # make a backup of the strings.xml in case of C^c
      File.rename @strings, "#{@strings}~"
      File.open(@strings, "w") do |f|
        f.puts doc.to_s
      end
      File.delete "#{@strings}~"
    end
  end

  def update_services services
    doc = Document.new(File.new @sql)
    doc.root.elements["string-array[@name='sql_insert_rss']"].delete_element 1

    services.each do |service|
      element = Element.new "item"
      # INSERT INTO rss (name, uid, type) VALUES (\'your name\', \'www.yourblog.org\', 1);
      text = CData.new "INSERT INTO rss (name, uid, type) VALUES (\\'#{service[2]}\\', " +
        "\\'#{service[1]}\\', #{service[0]});"
      element.add_text text
      doc.root.elements["string-array[@name='sql_insert_rss']"].add_element element
    end
    File.rename @sql, "#{@sql}~"
    File.open(@sql, "w") do |f|
      f.puts doc.to_s
    end
    File.delete "#{@sql}~"
  end

  def adb_install app, mode="debug"
    info _("installing the apk in the emulator...")
    # update project files
    cmd = "#{@adb} install -r -l #{@project_dir}/#{MUXIE_DIR}/bin/#{app}-#{mode}.apk"

    out = ""
    # capture the stderr from the terminal
    Open3.popen3(cmd) do |stdrin, stdout, stderr|
      out = stderr.read
    end

    if out.chop == "error: device not found"
      hint _("please start an AVD or create one if you don't have yet.")
      `#{@android} avd`
    end
  end

  def adb_uninstall package
    info _("uninstalling the app...")
    `#{@adb} uninstall #{package}`
  end

  def android_update_project app
    info _("updating project settings...")
    # update project
    `#{@android} update project --target 1 --name #{app} --path #{@project_dir}/#{MUXIE_DIR}`
  end

  def ant_debug
    # execute ant
    info _("generating apk file...")
    `cd #{@project_dir}/#{MUXIE_DIR} && ant debug -d -v`
  end

  def ant_release
    # execute ant
    info _("generating apk file...")

    if File.exists? "#{@project_dir}/#{MUXIE_DIR}/ant.properties"
      # TODO: tentar mostrar as mensagens do ant que pedem esses dados.
      hint _("enter keystore password and enter password for alias:")
    end

    `cd #{@project_dir}/#{MUXIE_DIR} && ant release -d -v`
  end

  def ant_clean
    info _("cleaning %s...") % "#{@project_dir}/#{MUXIE_DIR}"
    `cd #{@project_dir}/#{MUXIE_DIR} && ant clean`
  end

  def export_apk
    # FIXME: ...
    # verificar arquivos apk em bin/
    begin
      info _("copying apk files to #{@project_dir}/#{MUXIE_DIR}")
      entries = Dir.entries "#{@project_dir}/#{MUXIE_DIR}/bin/"
      entries.each do |apk|
        if apk =~ /.+(-debug|-release|-release-unsigned)(\.apk)$/
          FileUtils.cp "#{@project_dir}/#{MUXIE_DIR}/bin/#{apk}", "#{@project_dir}"
        end
      end
    rescue SystemCallError => ex
      error _("directory %s not found. Try 'muxie-maker test' or " +
        "'muxie-maker release' first.") % "#{@project_dir}/#{MUXIE_DIR}/bin/"
    rescue Exception => ex
      error ex
    end

    #info _("copying apk file to #{@project_dir}/#{MUXIE_DIR}")
    #`cp #{@project_dir}/#{MUXIE_DIR}/bin/#{app}-#{mode}.apk #{@project_dir}/#{MUXIE_DIR}`
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

  def debug msg
    puts "[debug] #{msg}"
  end
end
