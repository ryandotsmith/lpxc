require './lpxc.rb'
require 'minitest/autorun'

class LpxcTest < MiniTest::Unit::TestCase
  ENV['LOGPLEX_URL'] = 'https://east.logplex.io/logs' 

  def test_fmt
    c = Lpxc.new
    t = Time.now
    actual = c.fmt(t: t, token: 't.123', msg: 'hello world')
    ts = t.to_datetime.rfc3339.to_s
    expected =  "66 <190>1 #{ts} myhost t.123 lpxc - - hello world"
    assert_equal(expected, actual)
  end

  def test_flush_removes_data
    c = Lpxc.new(request_queue: SizedQueue.new(1))
    c.puts('hello world', 't.123')
    assert_equal(1, c.hash.keys.length)
    c.flush
    assert_equal(0, c.hash.keys.length)
  end

  def test_request_queue_with_single_token
    reqs = SizedQueue.new(1)
    c = Lpxc.new(request_queue: reqs)
    c.puts('hello world', 't.123')
    c.puts('hello world', 't.123')
    c.flush
    assert_equal(1, c.reqs.size)
  end

  def test_request_queue_with_many_tokens
    reqs = SizedQueue.new(2)
    c = Lpxc.new(request_queue: reqs)
    c.puts('hello world', 't.123')
    c.puts('hello world', 't.124')
    c.flush
    assert_equal(2, c.reqs.size)
  end

end
