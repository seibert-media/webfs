puts "WebFS starting"

require "http"
require "http/server"
require "ecr"
require "uri"
require "compress/zip"
require "file_utils"
require "mime"
require "./lib"

STDOUT.sync = true

# ARGUMENTS

# root
i = ARGV.index("--root")
root = Path[i ? ARGV[i + 1] : "~"].expand(home: true).normalize(remove_final_separator: true).to_s
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
server = HTTP::Server.new([
  HTTP::ErrorHandler.new,
  HTTP::MyLogHandler.new,
]) do |context|

  #
  # REQUEST
  #

  request, response = context.request, context.response
  request_path = URI.decode(request.path.gsub(/\/$/, nil))
  request_path_absolute = Path["#{root}/#{request_path}"].normalize.to_s
  
  # NOT FOUND
  if !File.exists?(request_path_absolute)
    response.respond_with_status(
      status: :not_found, 
      message: "can not find '#{request_path_absolute}'"
    )
    next
  end
  
  # PERISSION DENIED
  if !File.real_path(request_path_absolute).starts_with?(root)
    response.respond_with_status(
      status: :unauthorized, 
      message: "not allowed '#{request_path_absolute}'"
    )
    next
  end

  # POST
  if request.method == "POST"
    case request.content_type

    # UPLOAD
    when "multipart/form-data"
      HTTP::FormData.parse(request) do |part|
        case part.name
        when "file"
          name = filename_from_header part.headers["Content-Disposition"]
          if name
            target_path = Path[request_path_absolute].join(name).normalize.to_s
            puts "uploading #{target_path}"
            file = File.open target_path, "w" do |file|
              IO.copy part.body, file
            end
            File.chmod target_path, 0o777
          end
        end
      end
      response.status = HTTP::Status.new(302)
      response.headers["Location"] = request_path
      next

    # DELETE
    when "application/x-www-form-urlencoded"
      if request.post_params.fetch("_method", nil) == "DELETE"
        puts "deleting #{request_path_absolute}"
        if File.directory? request_path_absolute
          log "deleting directory '#{request_path_absolute}'"
          FileUtils.rm_rf request_path_absolute
        else
          log "deleting file '#{request_path_absolute}'"
          FileUtils.rm request_path_absolute
        end
      end
      response.status = HTTP::Status.new(302)
      response.headers["Location"] = Path[request_path].dirname.to_s
      next
    end
  end
  
  #
  # RESPONSE
  #
    
  # COFIRM DELETE
  if request.query_params["action"]? == "delete"
    response.content_type = "text/html"
    response.print ECR.render("templates/confirm_delete.ecr")
  
  # DOWNLOAD ZIP
  elsif request.query_params["action"]? == "download"
    puts "downloading directory '#{request_path_absolute}'"
    response.headers["Content-Type"] = "application/zip"
    response.headers["Content-Disposition"] = "attachment; filename=\"#{download_dirname(request_path)}\""
    Compress::Zip::Writer.open(response.output) do |zip|
      Dir.glob("#{request_path_absolute}/**/*", match_hidden: true).each do |entry|
        if File.directory?(entry)
          zip.add_dir(Path[entry].relative_to(request_path_absolute).to_s)
        elsif File.readable?(entry)
          zip.add Path[entry].relative_to(request_path_absolute).to_s, File.open(entry)
        else
          log "skipping '#{entry}': unreadable"
        end
      end
    end
  
  # INDEX
  elsif File.directory? request_path_absolute
    # build title
    elements = request_path.split('/')
    title_elements = elements.map_with_index do |element, i|
      elements[0..i].join("/")
    end
    # collect entries
    entries = Dir
      .glob("#{request_path_absolute}/*", match_hidden: true)
      .sort_by{ |entry| [File.directory?(entry) ? "0" : "1", entry.downcase] }
    # render
    response.content_type = "text/html"
    response.print ECR.render("templates/index.ecr")

  # DOWNLOAD
  elsif File.file? request_path_absolute
    puts "downloading file '#{request_path_absolute}'"
    if MIME.from_filename? request_path_absolute
      response.headers["Content-Type"] = MIME.from_filename request_path_absolute
    else
      response.headers["Content-Type"] = "application/octet-stream"
    end
    response.headers["Content-Disposition"] = "attachment; filename=\"#{File.basename request_path_absolute}\""
    File.open request_path_absolute, "r" do |file|
      IO.copy file, response.output
    end
  end
end

# start
address = server.bind_tcp listen, port
log "Listening on http://#{address}"
server.listen
