def log(entry : String)
  puts entry
  entry
end

def filename_from_header(header : String)
  filename_header = header.split(';').find{|e| /^filename=/ =~ e.strip}
  filename = filename_header.to_s.split("=")[1].gsub(/"/, nil)
  filename == "" ? nil : filename
end

def uri_encode_path(path : String)
  path.split("/").map{|element| URI.escape element}.join("/")
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
