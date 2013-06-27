require 'webrick'
require './lpxc.rb'
require 'minitest/autorun'

class LpxcTest < Minitest::Test
  ENV['LOGPLEX_URL'] = 'http://localhost:5000/logs'

  def serve_http(result)
    server = WEBrick::HTTPServer.new(
      Logger: WEBrick::Log.new("/dev/null"),
      AccessLog: [],
      :Port => 5000)
    server.mount_proc '/logs' do |req, res|
      result << req.body
    end
    server.start
  end

  def test_integration
    result = []
    Thread.new {serve_http(result)}
    c = Lpxc.new(request_queue: SizedQueue.new(1))
    c.start
    c.puts('hello world', 't.123')
    sleep(c.flush_interval * 2)

    expected = /66 <190>1 [0-9T:\+\-\.]+ myhost t.123 lpxc - - hello world/
    assert result[0] =~ expected
  end

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
