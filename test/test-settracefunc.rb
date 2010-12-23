require 'test/unit'
require 'rubygems'; require 'require_relative'
require_relative '../lib/set_trace'

class TestSetTraceFunc < Test::Unit::TestCase
  def test_basic
    events = []
    eval <<-EOF.gsub(/^.*?: /, "")
     1: set_trace_func(Proc.new { |event, file, lineno, mid, binding, klass|
     2:   events << [event, lineno, mid, klass]
     3: })
     4: x = 1 + 1
     5: set_trace_func(nil)
    EOF
    assert_equal(false, events.empty?)
  end
end
