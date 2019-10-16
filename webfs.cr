puts "WebFS starting"

require "http"
require "http/server"
require "ecr"
require "uri"
require "zip"
require "file_utils"
require "mime"
require "./lib"

STDOUT.sync = true

# ARGUMENTS
# root
i = ARGV.index("--root")
root = i ? ARGV[i + 1].gsub(/\/$/, nil) : Path["~"].expand.to_s
log "root '#{root}'"
# listen
i = ARGV.index("--listen")
listen = i ? ARGV[i + 1] : "127.0.0.1"
log "listen #{listen}"
# port
i = ARGV.index("--port")
port = i ? ARGV[i + 1].to_i : 3030
log "port #{port}"

# LOOP
server = HTTP::Server.new do |context|
  #
  # REQUEST
  #
  notice = permission_error = confirm_delete = nil
  request, response = context.request, context.response
  request_path = URI.decode(request.path.gsub(/\/$/, nil))
  request_path_absolute = Path["#{root}/#{request_path}"].normalize.to_s
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
          when "file"
            name = filename_from_header part.headers["Content-Disposition"]
            target_path = Path["#{request_path_absolute}/#{name}"].normalize.to_s
            if File.exists? target_path
              notice = log "file already exists '#{target_path}'"
            else
              file = File.open target_path, "w" do |file|
                IO.copy part.body, file
              end
              File.chmod target_path, 0o777
            end
          end
        end
        log "name '#{name}', file #{!!file}"
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
  download_filename = File.basename(request_path_absolute).download_filename
  if confirm_delete
    # COFIRM DELETE
    response.print ECR.render("templates/confirm_delete.ecr")
    log "confirm delete '#{relative_delete_path}'"
  elsif permission_error
    # NOT FOUND
    response.status = :unauthorized
    response.print "401"
    log "not allowed '#{request_path_absolute}'"
  elsif request.query_params.fetch("download", false) == "zip"
    # DOWNLOAD ZIP
    response.headers["Content-Type"] = "application/zip"
    response.headers["Content-Disposition"] = "attachment; filename=\"#{download_filename}\""
    Zip::Writer.open(response.output) do |zip|
      Dir.glob("#{request_path_absolute}/**/*").each do |target_path|
        next if File.directory? target_path
        next unless File.readable? target_path
        relative_path = target_path.relative_to request_path_absolute
        zip.add relative_path, File.open(target_path)
      end
    end
    log "download zipped '#{request_path_absolute}'"
  elsif File.directory? request_path_absolute
    log File.basename "/"
    
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
address = server.bind_tcp listen, port
puts "Listening on http://#{address}"
server.listen
