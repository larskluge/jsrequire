require File.dirname(__FILE__) + '/helper.rb'

class TestJsRequire < Test::Unit::TestCase

  def setup
    @fixtures_dir = File.join(File.dirname(__FILE__), "fixtures")
  end


  def assert_requires(file, javascripts, stylesheets = [])
    @jsrequire = JsRequire.new
    data = @jsrequire.resolve_dependencies(File.join(@fixtures_dir + "/javascripts", file))

    expect = [file, javascripts].flatten.map { |js| File.expand_path(js, @fixtures_dir + "/javascripts") }.sort
    assert_equal expect, data[:javascripts].sort
    assert_equal stylesheets, data[:stylesheets]
  end

  context "#resolve_dependencies" do

    should "return the basic hash with empty results" do
      @jsrequire = JsRequire.new
      data = @jsrequire.resolve_dependencies([])

      assert !data.include?(:bernd)

      assert data.include?(:javascripts)
      assert data.include?(:stylesheets)
    end

    should "require nothing" do
      assert_requires("norequire.js", [])
    end

    should "require recursive dependencies" do
      file = File.join(@fixtures_dir, "javascripts/a.js")

      @jsrequire = JsRequire.new File.join(@fixtures_dir, "different-place")
      data = @jsrequire.resolve_dependencies(file)

      expect = ["javascripts/norequire.js", "different-place/b.js", "javascripts/a.js"].map { |js| File.expand_path(js, @fixtures_dir) }
      assert_equal expect, data[:javascripts]
    end

    should "require recursive dependencies in right order" do
      files = ["different-place/b.js", "javascripts/c.js"].map { |f| File.join(@fixtures_dir, f) }

      @jsrequire = JsRequire.new File.join(@fixtures_dir, "different-place")
      data = @jsrequire.resolve_dependencies(files)

      expect = ["javascripts/norequire.js", "different-place/b.js", "javascripts/a.js", "javascripts/c.js"].map { |js| File.expand_path(js, @fixtures_dir) }
      assert_equal expect, data[:javascripts]
    end

    should "require one css file" do
      assert_requires("requirecss.js", [], ["style.css"])
    end

    should "resolve dependencies from loadpath with source file from different place" do
      loadpath = File.join(@fixtures_dir, "javascripts")
      @jsrequire = JsRequire.new(loadpath)

      source_file = File.join(@fixtures_dir, "different-place/b.js")
      dep = @jsrequire.resolve_dependencies(source_file)

      files = ["javascripts/norequire.js", "different-place/b.js"].map { |f| File.expand_path(f, @fixtures_dir) }
      assert_equal files, dep[:javascripts]
    end

    should "not be able to resolve dependent files because of missing loadpath" do
      @jsrequire = JsRequire.new
      source_file = File.join(@fixtures_dir, "different-place/b.js")
      required_file_found = true

      begin
        dep = @jsrequire.resolve_dependencies(source_file)
      rescue JsRequire::FileNotFoundInLoadpath
        required_file_found = false
      end

      assert !required_file_found, "load of required files should fail"
    end

    should "throw an exception when requiring a non existing file" do
      assert_raises JsRequire::FileNotFoundInLoadpath do
        assert_requires("require_non_existing_file.js", [])
      end
    end

    should "be able to require a file via namespaces" do
      assert_requires("require_namespaced_file.js", "namespace/a.js")
    end

    should "be able to require a file with dots in filename" do
      assert_requires("require_filename_with_dot.js", "file.with.dot.js")
    end

    should "be able to require namespaced files starting with 'js'" do
      assert_requires("require_filename_with_js.js", "namespace/json_reader.js")
    end

    should "check loadpaths" do
      additional_loadpath = File.join(@fixtures_dir, "different-place")
      extracted_loadpath = File.join(@fixtures_dir, "javascripts")
      files = ["norequire.js", "requirecss.js"].map { |f| File.join(extracted_loadpath, f) }
      @jsrequire = JsRequire.new(additional_loadpath)
      @jsrequire.resolve_dependencies(files)

      extracted_loadpaths = [File.expand_path(extracted_loadpath)]
      assert_equal extracted_loadpaths, @jsrequire.instance_eval("@extract_loadpaths")

      additional_loadpaths = [File.expand_path(additional_loadpath)]
      assert_equal additional_loadpaths, @jsrequire.instance_eval("@additional_loadpaths")
    end

  end



  context "helper methods" do

    should "#web_path_helper" do
      loadpath = File.join(@fixtures_dir, "javascripts")
      @jsrequire = JsRequire.new(loadpath)

      source_file = File.join(@fixtures_dir, "different-place/b.js")
      dep = @jsrequire.resolve_dependencies(source_file)

      absolute_files = ["javascripts/norequire.js", "different-place/b.js"].map { |f| File.expand_path(f, @fixtures_dir) }
      assert_equal absolute_files, dep[:javascripts]

      relative_files = ["/javascripts/norequire.js", "/different-place/b.js"]
      assert_equal relative_files, JsRequire::web_path_helper(dep[:javascripts], @fixtures_dir)

      relative_files = ["/javascripts/norequire.js", "/different-place/b.js"]
      assert_equal relative_files, JsRequire::web_path_helper(dep[:javascripts], [@fixtures_dir])

      other_relative_files = ["/bernd/norequire.js", "/baerbel/b.js"]
      assert_equal other_relative_files, JsRequire::web_path_helper(dep[:javascripts], {
        File.join(@fixtures_dir, "javascripts") => "/bernd",
        File.join(@fixtures_dir, "different-place") => "/baerbel"
      })
    end

    should "#namespace_helper" do
      js = ["/platform/public/javascripts/si/module/Hastenichtgesehen.js", "/platform/public/javascripts/si/desktop/Wurstwaren.js", "/platform/public/javascripts/si/applet/GeradNeu.js"]
      ns = ["si.applet", "si.desktop", "si.module"]

      assert_equal ns, JsRequire::namespace_helper(js, "si")
    end

  end

end

