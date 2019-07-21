puts "WebFS 1.0 starting"

require "http"
require "http/server"
require "ecr"
require "uri"
require "file_utils"
require "mime"
require "./lib"

# ARGUMENTS
i = ARGV.index("--root")
root = i ? ARGV[i + 1].gsub(/\/$/, nil) : "/"
log "root '#{root}'"

# LOOP
server = HTTP::Server.new do |context|
  #
  # REQUEST
  #
  notice = permission_error = confirm_delete = nil
  request, response = context.request, context.response
  request_path = URI.unescape(request.path.gsub(/\/$/, nil))
  request_path_absolute = "#{root}/#{Path[request_path].normalize}"
  log "#{request.method} '#{request_path}'"
  # POST
  if !File.real_path(request_path_absolute).starts_with?(root)
    permission_error = true
  else
    if request.method == "POST"
      name = file = nil
      case request.content_type
      when "multipart/form-data"
        # UPLOAD
        HTTP::FormData.parse(request) do |part|
          case part.name
          when "_method"
            method_param = part.body
          when "file"
            name = filename_from_header part.headers["Content-Disposition"]
            file = File.tempfile("upload") do |file|
              IO.copy(part.body, file)
            end
          end
        end
        log "name '#{name}', file #{!!file}"
        if name && file
          target_path = "#{request_path_absolute}/#{name}"
          if File.exists? target_path
            notice = log "file already exists '#{target_path}'"
          else
            log "moving '#{file.path}' to '#{target_path}'"
            File.rename file.path, "#{target_path}"
          end
        else
          notice = log "upload error"
          response.status = :bad_request
        end
      when "application/x-www-form-urlencoded"
        # DELETE
        if request.post_params.fetch("_method", nil) == "DELETE"
          relative_delete_path = request.post_params["path"]
          delete_path = "#{root}#{relative_delete_path}"
          if request.post_params.fetch("confirm", nil) == "true"
            if File.directory? delete_path
              log "deleting recursively '#{relative_delete_path}'"
              FileUtils.rm_rf delete_path
            else
              log "deleting '#{relative_delete_path}'"
              FileUtils.rm delete_path
            end
          else
            confirm_delete = true
          end
        end
      end
    end
  end
  #
  # RESPONSE
  #
  response.content_type = "text/html"
  if confirm_delete
    # COFIRM DELETE
    response.print ECR.render("templates/confirm_delete.ecr")
    log "confirm delete '#{relative_delete_path}'"
  elsif permission_error
    # NOT FOUND
    response.status = :unauthorized
    response.print "401"
    log "not allowed '#{request_path_absolute}'"
  elsif File.directory? request_path_absolute
    # INDEX
    # build title
    elements = request_path.split('/')
    title_elements = elements.map_with_index do |element, i|
      root + elements[0..i].join("/")
    end
    # collect entries
    entries = Dir["#{request_path_absolute}/*"].map{|entry| entry}
    dirs = entries.select{|entry| File.directory? entry}.sort
    files = (entries - dirs).sort
    sorted_entries = dirs + files
    # render
    response.print ECR.render("templates/index.ecr")
    log "index #{sorted_entries.size} entries"
  elsif File.exists? request_path_absolute
    # DOWNLOAD
    if MIME.from_filename? request_path_absolute
      response.headers["Content-Type"] = MIME.from_filename request_path_absolute
    else
      response.headers["Content-Type"] = "application/octet-stream"
    end
    response.headers["Content-Disposition"] = "attachment; filename=\"#{File.basename request_path_absolute}\""
    File.open request_path_absolute, "r" do |f|
      IO.copy f, response.output
    end
    log "download #{request_path_absolute}'"
  else
    # NOT FOUND
    response.status = :not_found
    response.print "404"
    log "can not find '#{request_path_absolute}'"
  end
end

# start
address = server.bind_tcp 3030
puts "Listening on http://#{address}"
server.listen
