def log(entry)
  puts entry.to_s
  entry
end

def filename_from_header(header : String)
  filename_header = header.split(';').find{ |e| /^filename=/ =~ e.strip }
  filename = filename_header.to_s.split("=")[1].gsub(/"/, nil)
  filename == "" ? nil : filename
end

def download_dirname(path)
  (File.basename(path).blank? ? "root" : File.basename(path)).lstrip(".") + ".zip"
end

def uri_encode_path(path : String)
  path
    .split("/")
    .map{ |element| URI.encode_path element }
    .join("/")
end

class HTTP::Request
  def content_type
    headers["Content-Type"].split(";")[0]
  end
  
  def post_params
    @post_params ||= if body
      HTTP::Params.parse(body.not_nil!.gets_to_end)
    else
       {} of String => String
    end
  end
end

# format int as si
struct Int
  def to_si
    size = self
    i = 0
    while (current_size = size.to_f/2**10) > 1
      size = current_size
      i += 1
    end
    if i > 0 && (decimals = 3 - size.to_i.to_s.size) > 0
      sprintf "%.#{decimals}f", size
    else
      size.to_i.to_s
    end + " " + %w(B KiB MiB GiB TiB PiB EiB ZiB YiB)[i]
  end
end

class HTTP::MyLogHandler
  include HTTP::Handler

  def call(context) : Nil
    start = Time.monotonic

    begin
      call_next(context)
    ensure
      puts [
        context.request.method,
        context.request.resource,
        context.request.version,
        "-",
        context.response.status_code,
        (Time.monotonic - start).total_seconds.humanize(precision: 2, significant: false).to_s + "s",
      ].join(" ")
    end
  end
end
