require 'rubygems'
require 'test/unit'
require 'shoulda'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

begin
  require 'redgreen'
rescue Exception
end


require 'jsrequire'

class Test::Unit::TestCase
end

