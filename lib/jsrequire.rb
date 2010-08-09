class JsRequire
  ALLOWED_EXTENSIONS = %w(coffee js)

  class FileNotFoundInLoadpath < ArgumentError; end


  def initialize(loadpaths = nil)
    @extract_loadpaths = []

    loadpaths = [loadpaths] unless loadpaths.is_a?(Array)
    @additional_loadpaths = JsRequire::normalize_filepaths(loadpaths.compact)

    @preprocessors = Hash.new { |h,k| h[k] = [] }

    on("css", &method(:collect_css))
  end


  def on(action = nil, &block)
    @preprocessors[action] << block
  end


  def collect_css(action, param)
    @css << param + ".css"
    nil
  end


  # resolve dependencies of js input files
  #
  # returns a hash with js and css dependencies
  #
  # js files are returned with absolute filepaths,
  # css files not. css files are returned as given
  # by the parsed require statement.
  #
  # e.g.
  #
  # {
  #   :javascripts => ["/foo/bar.js"],
  #   :stylesheets => ["style.css"]
  # }
  #
  def resolve_dependencies(files)
    files = [files] unless files.is_a?(Enumerable)

    @css = []
    @extract_loadpaths = extract_loadpaths(files)

    js = extract_dependencies_recursive(JsRequire::normalize_filepaths(files))

    {
      :javascripts => js,
      :stylesheets => @css.uniq.sort
    }
  end


  # convert absolute filepaths to relatives by
  # cutting the absolute path to the webroot
  #
  # returns the webroot relative filepaths
  #
  # web_path_helper(["/foo/bar.js"], {"/foo" => "/javascripts"})
  #   => ["/javascripts/bar.js"]
  #
  # @param webroots: array of strings to remove the prefix path
  #                  or a hash to replace with defined string
  #
  def self.web_path_helper(files, webroots)
    webroots = [webroots] unless webroots.is_a?(Enumerable)

    files.map do |f|
      rel_file = nil
      webroots.each do |wr, replacement|
        wr = normalize_filepath(wr)
        rel_file = f.sub(/^#{Regexp.escape wr}/, replacement || '')
        break if rel_file != f
      end
      rel_file || f
    end
  end


  # builds namespaces from script files by pathnames
  # when the <namespace_prefix> is found in path.
  #
  # e.g.
  #
  # namespace_helper(["/foo/bar/quux/file1.js", "/foo/bar/baz/file2.js"], "bar")
  #   => ["bar.baz", "bar.quux"]
  #
  # Interessting for ExtJs#namespace
  #
  def self.namespace_helper(files, namespace_prefix)
    files.inject([]) do |arr,js|
      if js =~ /\/(#{namespace_prefix}\/.+)$/
        file = File.dirname($1).gsub("/", ".")
        arr << file
      end
      arr
    end.sort.uniq
  end



  protected


  def self.normalize_filepath(file)
    File.expand_path(file)
  end


  def self.normalize_filepaths(files)
    files.map { |f| normalize_filepath(f) }
  end


  def extract_loadpaths(files)
    JsRequire::normalize_filepaths(files.map { |f| File.dirname(f) }.uniq)
  end



  def is_file?(filename)
    File.file?(filename) && File.readable?(filename) && filename =~ /^\//
  end


  def find_file_with_extension(filename, current_dir = nil)
    return filename if is_file?(filename)

    loadpaths = @extract_loadpaths + @additional_loadpaths
    loadpaths.unshift(current_dir) if current_dir && filename =~ /^\./
    loadpaths.each do |path|
      file = File.expand_path(filename, path)
      return file if is_file?(file)
    end

    # fallback for namespaced files
    if filename =~ /\./
      loadpaths.each do |path|
        ext = File.extname(filename)
        file = File.expand_path(filename.gsub(/#{ext}$/, '').gsub(/^\./, '').gsub('.', '/') + ext, path)
        return file if is_file?(file)
      end
    end

    false
  end

  def find_file(filename, current_dir = nil)
    file = false

    file = find_file_with_extension(filename, current_dir)
    return file unless file == false

    ALLOWED_EXTENSIONS.each do |extension|
      file = find_file_with_extension("#{filename}.#{extension}", current_dir)
      return file unless file == false
    end

    raise FileNotFoundInLoadpath, "File '#{filename}' not found in loadpaths '#{(@extract_loadpaths + @additional_loadpaths).join("', '")}'."
  end

  def exec_preprocessor(action, parameter)
    trigger = Proc.new do |cb|
      res = cb.call(action, parameter)
      action, parameter = res if res.is_a?(Array) && res.size == 2
    end

    @preprocessors[action].each(&trigger)
    @preprocessors[nil].each(&trigger)

    [action, parameter]
  end

  def extract_dependencies(filename)
    is_require = true
    js = []

    File.open(filename, "r").each_line do |line|
      if val = parse_line(line)
        # fire callbacks
        action, parameter = exec_preprocessor(val[0], val[1])

        case action
        when "js" then js << parameter
        end
      else
        break
      end
    end

    js.uniq.map { |f| find_file(f, File.dirname(filename)) }
  end

  def parse_line(line)
    case line
    when /^
          \s*         # optional leading whitespace
          \/\*\s*     # opening comment
          (\w+)\s+    # action
          (.*)        # parameter
          \*\/\s*$    # closing comment
        /x then
      [$1, $2.strip]
    when /^
          \s*         # optional leading whitespace
          \#\s*       # opening comment
          (\w+)\s+    # action
          (.*)$       # parameter
        /x then
      [$1, $2.strip]
    else
      nil
    end
  end


  def extract_dependencies_recursive(files, included_files = [])
    js = []
    files.each do |f|
      file = find_file(f)

      unless included_files.include?(file)
        js += extract_dependencies_recursive(extract_dependencies(file), js + [file] + included_files)
        js << file
      end
    end

    js
  end

end

