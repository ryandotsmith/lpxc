require 'thread'
require 'webrick'
require './lib/lpxc.rb'

Thread.abort_on_exception = true

LOGPLEX_URL = URI('http://localhost:5000/logs')
ENV['LOGPLEX_URL'] = LOGPLEX_URL.to_s

case RUBY_VERSION
when "1.8.7"
  require 'test/unit'
  LpxcTestBase = Test::Unit::TestCase
when "1.9.3", "2.0.0"
  require 'minitest/autorun'
  LpxcTestBase = MiniTest::Unit::TestCase
else
  raise("Unsupported ruby version: #{RUBY_VERSION}")
end

module TestServer #:nodoc:
  def self.results; @results; end
  def self.stop; @server.shutdown; end
  def self.start
    @results = []
    @server = WEBrick::HTTPServer.new(
      :Logger => WEBrick::Log.new("/dev/null"),
      :AccessLog => [],
      :Port => LOGPLEX_URL.port)
    @server.mount_proc(LOGPLEX_URL.path) {|req, res| @results << req.body}
    @server_thread = Thread.new {@server.start}
  end
end

class LpxcTest < LpxcTestBase #:nodoc:

  def setup
    TestServer.start
  end

  def teardown
    TestServer.stop
  end

  def test_integration
    c = Lpxc.new(
      :flush_interval=> 0.2,
      :batch_size => 1,
      :max_reqs_per_conn=> 1,
      :request_queue => SizedQueue.new(1))
    c.puts('hello world', 't.123')
    c.wait
    expected = /66 <190>1 [0-9T:\+\-\.]+ myhost t.123 lpxc - - hello world/
    assert TestServer.results[0] =~ expected
  end

  def test_integration_batching
    batch_size = 100
    c = Lpxc.new(
      :request_queue => SizedQueue.new(1),
      :flush_interval => 10,
      :batch_size => batch_size
    )
    batch_size.times do
      c.puts('hello world', 't.123')
    end
    c.wait
    assert_equal(1, TestServer.results.length)
    assert_equal(batch_size, TestServer.results[0].scan(/hello\sworld/).count)
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
    h = {}
    c = Lpxc.new(:hash => h, :request_queue => SizedQueue.new(1))
    c.puts('hello world', 't.123')
    assert_equal(1, h.keys.length)
    c.send(:flush)
    c.wait
    assert_equal(0, h.keys.length)
  end

  def test_request_queue_with_single_token
    reqs = SizedQueue.new(1)
    c = Lpxc.new(:request_queue => reqs, :batch_size => 2)
    c.puts('hello world', 't.123')
    c.puts('hello world', 't.123')
    c.wait
    assert_equal(1, TestServer.results.length)
  end

  def test_request_queue_with_many_tokens
    reqs = SizedQueue.new(2)
    c = Lpxc.new(:request_queue => reqs, :batch_size => 2)
    c.puts('hello world', 't.123')
    c.puts('hello world', 't.124')
    c.wait
    assert_equal(2, TestServer.results.length)
  end
end
