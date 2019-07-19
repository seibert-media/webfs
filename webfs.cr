require "http"
require "http/server"
require "ecr"

# arguments
i = ARGV.index("--root")
root = i ? ARGV[i + 1] : "/"
i = ARGV.index("--password")
password = i ? ARGV[i + 1] : nil

def human_readable(size : Int32)
  i = 0
  while (current_size = size/2**10) > 1
    size = current_size
    i += 1
  end
  [size, [nil, "KMGTPYZ".split("")].flatten[i]].join
end

# loop
server = HTTP::Server.new do |context|
  context.response.content_type = "text/html"
  method = context.request.method
  if password && password != context.request.query_params.fetch("password", nil)
    #
    # PERMISSION ERROR
    #
    context.response.print "permission error"
  elsif method == "GET"
    #
    # GET
    #
    requested_path = "#{root}#{context.request.path}"
    entries = Dir["#{requested_path}/*"]
    dirs =  entries.select{|entry| File.directory? entry}.sort
    files = entries - dirs
    sorted_entries = dirs + files
    context.response.print ECR.render("index.ecr")
  elsif method == "POST"
    #
    # POST
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

# start
address = server.bind_tcp 3030
puts "Listening on http://#{address}"
server.listen
