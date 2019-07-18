require "http"
require "http/server"
require "ecr"

i = ARGV.index("--root")
root = i ? ARGV[i + 1] : "/"

server = HTTP::Server.new do |context|
  method = context.request.method
  if method == "GET"
    #
    # GET
    #
    context.response.content_type = "text/html"
    files = Dir["#{root}/*"].map{|file| File.basename file}
    context.response.print ECR.render("index.ecr")
    
  elsif method == "POST"
    #
    # PUST
    #
    name = nil
    file = nil
    HTTP::FormData.parse(context.request) do |part|
      case part.name
      when "path"
        name = part.body.gets_to_end
      when "file"
        file = File.tempfile("upload") do |file|
          IO.copy(part.body, file)
        end
      end
    end
    unless name && file
      context.response.status = :bad_request
      next
    end
    context.response << file.path
  elsif method == "DELETE"
    #
    # DELETE
    #
  end
end

address = server.bind_tcp 3030
puts "Listening on http://#{address}"
server.listen
