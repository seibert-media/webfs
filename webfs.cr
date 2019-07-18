require "http"
require "http/server"

server = HTTP::Server.new do |context|
  method = context.request.method
  if method == "GET"
    # GET
    context.response.content_type = "text/plain"
    context.response.print "Hello world!"
  elsif method == "POST"
    # PUST
    name = file = nil
    HTTP::FormData.parse(context.request) do |part|
      case part.name
      when "name"
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
    p context.request.path
  end
end

address = server.bind_tcp 3030
puts "Listening on http://#{address}"
server.listen
