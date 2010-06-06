class JsRequire

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


  def find_file(filename)
    return filename if is_file?(filename)

    loadpaths = @extract_loadpaths + @additional_loadpaths
    loadpaths.each do |path|
      file = File.expand_path(filename, path)
      return file if is_file?(file)
    end

    # fallback for namespaced files
    if filename =~ /\./
      loadpaths.each do |path|
        ext = File.extname(filename)
        file = File.expand_path(filename.gsub(/#{ext}$/, '').gsub('.', '/') + ext, path)
        return file if is_file?(file)
      end
    end

    raise FileNotFoundInLoadpath, "File '#{filename}' not found in loadpaths '#{loadpaths.join("', '")}'."
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
      if line =~ /^\s*\/\*\s*(\w+)(.+)\*\/\s*$/
        action = $1.strip
        parameter = $2.strip

        # fire callbacks
        #
        action, parameter = exec_preprocessor(action, parameter)

        case action
        when "js" then js << "#{parameter}.js"
        end
      else
        break
      end
    end

    js.uniq.map { |f| find_file(f) }
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

