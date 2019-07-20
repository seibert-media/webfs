puts "WebFS 1.0 starting"

require "http"
require "http/server"
require "ecr"
require "uri"
require "file_utils"
require "./lib"

# arguments
i = ARGV.index("--root")
root = i ? ARGV[i + 1].gsub(/\/$/, nil) : "/"
log "root '#{root}'"
notice = nil

############################# LOOP
server = HTTP::Server.new do |context|
  method = context.request.method
  if context.request.body
    post_params = HTTP::Params.parse context.request.body.not_nil!.gets_to_end
    method = "DELETE" if post_params.fetch("_method", "") == "DELETE"
  end
  request_path = URI.unescape(context.request.path.gsub(/\/$/, nil))
  request_path_absolute = "#{root}/#{Path[request_path].normalize}"
  log "#{method} '#{request_path}'"
  ############################# POST
  if method == "POST"
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
  ############################# DELETE
  if method == "DELETE"
    relative_delete_path = post_params.not_nil!["path"]
    delete_path = "#{root}#{relative_delete_path}"
    if post_params.not_nil!.fetch("confirm", nil) == "true"
      if File.directory? delete_path
        log "deleting recursively '#{relative_delete_path}'"
        #FileUtils.rm_rf delete_path
      else
        log "deleting '#{relative_delete_path}'"
        #FileUtils.rm delete_path
      end
    end
  end
  ############################# RENDER
  context.response.content_type = "text/html"
  if method == "DELETE" && post_params.not_nil!.fetch("confirm", nil) != "true"
    ############################# COFIRM DELETE
    log "confirm delete '#{relative_delete_path}'"
    context.response.print ECR.render("confirm_delete.ecr")
  elsif File.directory? request_path_absolute
    ############################# INDEX
    # build title
    elements = request_path.split('/')
    title_elements = elements.map_with_index do |element, i|
      root + elements[0..i].join("/")
    end
    # collect entries
    entries = Dir["#{request_path_absolute}/*"].map { |entry| entry }
    entries = entries.select{|e| !File.symlink? e}
    dirs = entries.select { |entry| File.directory? entry }.sort
    files = (entries - dirs).sort
    sorted_entries = dirs + files
    log "index #{sorted_entries.size} entries"
    # render
    context.response.print ECR.render("index.ecr")
  elsif File.exists? request_path_absolute
    ############################# FILE
    log "download #{request_path_absolute}'"
    context.response.headers["Content-Type"] = "application/octet-stream"
    context.response.headers["Content-Disposition"] = "attachment; filename=\"#{File.basename request_path_absolute}\""
    File.open request_path_absolute, "r" do |f|
      IO.copy f, context.response.output
    end
  else
    ############################# NOT FOUND
    log "can not find '#{request_path_absolute}'"
    context.response.status = :not_found
    context.response.print "404"
  end
  notice = nil # reset
end

# start
address = server.bind_tcp 3030
puts "Listening on http://#{address}"
server.listen
