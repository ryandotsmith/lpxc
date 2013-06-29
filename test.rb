require 'webrick'
require './lpxc.rb'

LOGPLEX_URL = URI('http://localhost:5000/logs')
ENV['LOGPLEX_URL'] = LOGPLEX_URL.to_s

if RUBY_VERSION[0].to_i >= 2
  require 'minitest/autorun'
  LpxcTestBase = Minitest::Test
else
  require 'test/unit'
  LpxcTestBase = Test::Unit::TestCase
end

module TestServer
  def self.start
    clear_results
    @server = WEBrick::HTTPServer.new(
      :Logger => WEBrick::Log.new("/dev/null"),
      :AccessLog => [],
      :Port => LOGPLEX_URL.port)
    @server.mount_proc(LOGPLEX_URL.path) {|req, res| @results << req.body}
    @server_thread = Thread.new {@server.start}
  end

  def self.stop
    @server.shutdown
  end

  def self.clear_results; @results = []; end
  def self.results; @results; end
end

class LpxcTest < LpxcTestBase

  def setup
    TestServer.start
  end

  def teardown
    TestServer.stop
  end

  def test_integration
    c = Lpxc.new(:request_queue => SizedQueue.new(1))
    c.start
    c.puts('hello world', 't.123')
    sleep(c.flush_interval * 2)

    expected = /66 <190>1 [0-9T:\+\-\.]+ myhost t.123 lpxc - - hello world/
    assert TestServer.results[0] =~ expected
  end

  def test_integration_batching
    c = Lpxc.new(
      :request_queue => SizedQueue.new(1),
      :flush_interval => 10,
      :batch_size => 100
    )

    c.start
    c.batch_size.times do
      c.puts('hello world', 't.123')
    end

    sleep(0.5) #allow some time for lpxc to make the http request.
    assert_equal(1, TestServer.results.length)
    assert_equal(c.batch_size, TestServer.results[0].scan(/hello\sworld/).count)
  end

  def test_fmt
    c = Lpxc.new
    t = Time.now.utc
    actual = c.send(:fmt, {:t => t, :token => 't.123', :msg => 'hello world'})
    ts = t.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    expected =  "66 <190>1 #{ts} myhost t.123 lpxc - - hello world"
    assert_equal(expected, actual)
  end

  def test_flush_removes_data
    c = Lpxc.new(:request_queue => SizedQueue.new(1))
    c.puts('hello world', 't.123')
    assert_equal(1, c.hash.keys.length)
    c.send(:flush)
    assert_equal(0, c.hash.keys.length)
  end

  def test_request_queue_with_single_token
    reqs = SizedQueue.new(1)
    c = Lpxc.new(:request_queue => reqs)
    c.puts('hello world', 't.123')
    c.puts('hello world', 't.123')
    c.send(:flush)
    assert_equal(1, c.reqs.size)
  end

  def test_request_queue_with_many_tokens
    reqs = SizedQueue.new(2)
    c = Lpxc.new(:request_queue => reqs)
    c.puts('hello world', 't.123')
    c.puts('hello world', 't.124')
    c.send(:flush)
    assert_equal(2, c.reqs.size)
  end

end
