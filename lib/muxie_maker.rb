require "open-uri"

class MuxieMaker

  EMPTY_DIR = 2 # . and .. are listed in #Dir.entries
  MUXIE_JSON = "muxie.json"
  MUXIE_DIR = "mad3-muxie"

  def initialize
    @project_dir = Dir.pwd
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
