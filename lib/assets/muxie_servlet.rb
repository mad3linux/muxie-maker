require 'webrick'
include WEBrick

class MuxieServlet < HTTPServlet::AbstractServlet
  def do_GET(req, response)
    File.open(File.dirname(__FILE__) + "/index.rhtml",'r') do |f|
		  @template = ERB.new(f.read)
    end
    response.body = @template.result(binding)
    response['Content-Type'] = "text/html"
  end
end