require File.dirname(__FILE__) + '/helper.rb'

class TestHooks < Test::Unit::TestCase

  def setup
    @fixtures_dir = File.join(File.dirname(__FILE__), "fixtures")
  end

  def require(file, &block)
    @jsrequire = JsRequire.new

    yield

    data = @jsrequire.resolve_dependencies(File.join(@fixtures_dir + "/javascripts", file))
  end


  context "hooks" do

    should "register hook successfully" do
      @jsrequire = JsRequire.new
      @jsrequire.on { |action, parameter| }
    end

    should "execute general hook" do
      called = false

      require("hook.js") do
        @jsrequire.on do |action, parameter|
          assert_equal "view", action
          assert_equal "hello world", parameter
          called = true
        end
      end

      assert called, "Callback was not called"
    end

    should "execute specific hook" do
      called = false
      require("hook.js") do
        @jsrequire.on("view") do |action, parameter|
          assert_equal "view", action
          assert_equal "hello world", parameter
          called = true
        end
      end

      assert called, "Callback was not called"
    end

    should "call specific hook before general" do
      specific_called = false
      general_called = false

      require("hook.js") do
        @jsrequire.on do |action, parameter|
          assert specific_called, "Specific was not called before"
          general_called = true
        end
        @jsrequire.on("view") do |action, parameter|
          assert !general_called, "General was called before"
          specific_called = true
        end
      end

      assert general_called && specific_called, "Callbacks were not called"
    end

    should "rewrite line to js-action" do
      called = false
      deps = require("hook.js") do
        @jsrequire.on("view") do |action, params|
          called = true
          ["js", "norequire"]
        end
      end

      assert called, "Callback not fired"
      assert_equal 2, deps[:javascripts].size
      assert_match /norequire\.js$/, deps[:javascripts].first
    end

    should "skip required view because hook drops it" do
      called = false
      deps = require("hook.js") do
        @jsrequire.on("view") do |action, params|
          called = true
          nil
        end
      end

      assert called, "Callback not fired"
      assert_equal 1, deps[:javascripts].size
      assert_match /hook\.js$/, deps[:javascripts].first
    end

  end

end

