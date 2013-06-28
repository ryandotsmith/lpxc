require 'webrick'
require './lpxc.rb'

if RUBY_VERSION[0].to_i >= 2
  require 'minitest/autorun'
  LpxcTestBase = Minitest::Test
else
  require 'test/unit'
  LpxcTestBase = Test::Unit::TestCase
end

module TestServer
  def self.start(result)
    @server = WEBrick::HTTPServer.new(
      :Logger => WEBrick::Log.new("/dev/null"),
      :AccessLog => [],
      :Port => 5000)
    @server.mount_proc('/logs') {|req, res| result << req.body}
    @server_thread = Thread.new {@server.start}
  end

  def self.stop
    @server.shutdown
  end
end

class LpxcTest < LpxcTestBase
  ENV['LOGPLEX_URL'] = 'http://localhost:5000/logs'

  def test_integration
    result = []
    TestServer.start(result)

    c = Lpxc.new(:request_queue => SizedQueue.new(1))
    c.start
    c.puts('hello world', 't.123')
    sleep(c.flush_interval * 2)

    expected = /66 <190>1 [0-9T:\+\-\.]+ myhost t.123 lpxc - - hello world/
    assert result[0] =~ expected
  end

  def test_fmt
    c = Lpxc.new
    t = Time.now.utc
    actual = c.fmt(:t => t, :token => 't.123', :msg => 'hello world')
    ts = t.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    expected =  "66 <190>1 #{ts} myhost t.123 lpxc - - hello world"
    assert_equal(expected, actual)
  end

  def test_flush_removes_data
    c = Lpxc.new(:request_queue => SizedQueue.new(1))
    c.puts('hello world', 't.123')
    assert_equal(1, c.hash.keys.length)
    c.flush
    assert_equal(0, c.hash.keys.length)
  end

  def test_request_queue_with_single_token
    reqs = SizedQueue.new(1)
    c = Lpxc.new(:request_queue => reqs)
    c.puts('hello world', 't.123')
    c.puts('hello world', 't.123')
    c.flush
    assert_equal(1, c.reqs.size)
  end

  def test_request_queue_with_many_tokens
    reqs = SizedQueue.new(2)
    c = Lpxc.new(:request_queue => reqs)
    c.puts('hello world', 't.123')
    c.puts('hello world', 't.124')
    c.flush
    assert_equal(2, c.reqs.size)
  end

end
