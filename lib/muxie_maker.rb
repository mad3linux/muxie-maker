require "open-uri"
require "rexml/document"

class MuxieMaker

  include REXML

  EMPTY_DIR = 2 # ./ and ../ are listed in #Dir.entries
  MUXIE_JSON = "muxie.json"
  MUXIE_DIR = "mad3-muxie"

  def initialize
    @project_dir = Dir.pwd
    @android = `which android`.chop
    @adb = `which adb`.chop
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
    File.exists? "#{@project_dir}/#{MUXIE_JSON}"
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

  def info msg
    puts "[info] #{msg}"
  end

  def error msg
    puts "[error] #{msg}"
  end

  def hint msg
    puts "[hint] #{msg}"
  end

end
