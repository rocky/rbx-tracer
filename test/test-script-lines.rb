require 'test/unit'
require 'rubygems'; require 'require_relative'
require_relative '../lib/script_lines'
SCRIPT_LINES__ = {}
class Test_SCRIPT_LINES__ < Test::Unit::TestCase
  def test_basic
    dir = File.dirname(__FILE__)
    file = File.join(dir, '../lib/set_trace.rb')
    load file
    assert_equal true, SCRIPT_LINES__.keys.member?(file)
    assert_equal Array, SCRIPT_LINES__[file].class
    assert_equal "# -*- coding: utf-8 -*-\n", SCRIPT_LINES__[file][0]
    assert_equal true, SCRIPT_LINES__[file].size > 10
  end
end
