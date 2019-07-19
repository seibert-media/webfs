puts "WebFS 1.0 starting"

require "http"
require "http/server"
require "ecr"
require "uri"
require "file_utils"

def log(entry : String)
  puts entry
  entry
end

def filename_from_header(header : String)
  filename_header = header.split(';')
    .find{|e| /^filename=/ =~ e.strip}
  if filename_header 
    filename_header.split("=")[1].gsub(/"/, nil)
  else
    log "no filename in header '#{header}'"
  end
end

# get relative path
class String
  def relative_to(root : String)
    self.to_s[root.size..-1]
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
log "root '#{root}'"

notice = nil

# loop
server = HTTP::Server.new do |context|
  context.response.content_type = "text/html"
  method = context.request.method
  # get post params
  if context.request.body
    post_params = HTTP::Params.parse context.request.body.not_nil!.gets_to_end
    p post_params
    method = "DELETE" if post_params.fetch("_method", "") == "DELETE"
  end
  request_path = URI.unescape(
    context.request.path.gsub(/\/$/, nil)
  )
  request_path_absolute = "#{root}#{request_path}"
  log "#{method} '#{request_path}'"
  if method == "POST"
    # POST
    name = file = nil
    HTTP::FormData.parse(context.request) do |part|
      if part.name == "file"
        name = filename_from_header part.headers["Content-Disposition"]
        file = File.tempfile("upload") do |file|
          IO.copy(part.body, file)
        end
      end
    end
   log "name '#{name}', file #{!!file}"
    unless name && file
      log "name or file missing"
      context.response.status = :bad_request
      next
    end
    target_path = "#{request_path_absolute}/#{name}"
    if File.exists? target_path
      notice = log "file already exists '#{target_path}'"
    else
      log "moving '#{file.path}' to '#{target_path}'"
      File.rename file.path, "#{target_path}"
    end
  end
  if ["GET", "POST", "DELETE"].includes? method
    if File.directory? request_path_absolute
      # GET
      ## title
      elements = request_path.split('/')
      title_elements = elements.map_with_index do |element, i|
        root + elements[0..i].join("/")
      end
      ## entries
      entries = Dir["#{request_path_absolute}/*"].map { |entry| entry }
      dirs = entries.select { |entry| File.directory? entry }.sort
      files = (entries - dirs).sort
      sorted_entries = dirs + files
      log "index #{sorted_entries.size} entries"
      context.response.print ECR.render("index.ecr")
    elsif File.exists? request_path_absolute
      log "download #{request_path_absolute}'"
      context.response.print "file"
    else
      log "can not find '#{request_path_absolute}'"
      context.response.status = :not_found
      context.response.print "404"
    end
  end
  if method == "DELETE"
    delete_path = "#{root}#{post_params.not_nil!["path"]}"
    # DELETE
    if File.directory? delete_path
      log "deleting recursively '#{delete_path}'"
      #FileUtils.rm_rf request_path_absolute
    else
      log "deleting '#{delete_path}'"
      #FileUtils.rm request_path_absolute
    end
  end
  notice = nil # reset
end

# start
address = server.bind_tcp 3030
puts "Listening on http://#{address}"
server.listen
