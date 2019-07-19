require "http"
require "http/server"
require "ecr"
require "uri"

def log(entry : String)
  puts entry
end

# get relative path
class String
  def relative_to(root : String)
    self.to_s[root.size..-1]
  end

  def absolute_in(root : String)
  end
end

# format int as si
struct Int
  def to_si
    size = self
    i = 0
    while (current_size = size/2**10) > 1
      size = current_size
      i += 1
    end
    [size, [nil, "KMGTPYZ".split("")].flatten[i]].join
  end
end

# arguments
i = ARGV.index("--root")
root = i ? ARGV[i + 1].gsub(/\/$/, nil) : "/"

# loop
server = HTTP::Server.new do |context|
  context.response.content_type = "text/html"
  method = context.request.method
  request_path = URI.unescape context.request.path.gsub(/\/$/, nil)
  request_path_absolute = "#{root}#{request_path}"
  
  p request_path_absolute
  p File.exists? request_path_absolute
  
  if method == "GET"
    if File.directory? request_path_absolute
      #
      # GET
      #
      # # title
      elements = request_path.split('/')
      title_elements = elements.map_with_index do |element, i|
        root + elements[0..i].join("/")
      end
      # # entries
      entries = Dir["#{request_path_absolute}/*"].map { |entry| entry }
      dirs = entries.select { |entry| File.directory? entry }.sort
      files = (entries - dirs).sort
      sorted_entries = dirs + files
      context.response.print ECR.render("index.ecr")
    elsif File.exists? request_path_absolute
      context.response.print "file"
    else
      context.response.status = :not_found
      context.response.print "404"
    end
  elsif method == "POST"
    #
    # POST
    #
    name = nil
    file = nil
    HTTP::FormData.parse(context.request) do |part|
      if part.name == "file"
        # name
        filename_header = part.headers["Content-Disposition"].split(';')
          .find{|e| /^filename=/ =~ e.strip}
        if filename_header 
          name = filename_header.split("=")[1].gsub(/"/, nil)
        else
          log "filename not found ind header: #{part.headers}"
        end
        # file
        file = File.tempfile("upload") do |file|
          IO.copy(part.body, file)
        end
      end
    end
    unless name && file
      context.response.status = :bad_request
      next
    end
    File.rename file.path, "#{request_path_absolute}/#{name}"
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
