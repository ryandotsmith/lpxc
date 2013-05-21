$stdout.sync = true

require 'net/http'
require 'uri'
require 'thread'

Thread.abort_on_exception = true

module Lpxc
  LOGPLEX_URL = URI(ENV["LOGPLEX_URL"])
  @hostname = "lpxc_example"
  @mut = Mutex.new
  @buf = SizedQueue.new(300)
  @reqs = SizedQueue.new(300)

  def self.puts(tok, msg)
    @buf.enq({
      ts: Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ+00:00"), 
      token: tok, 
      msg: msg})
  end

  def self.start
    Thread.new {outlet}
    loop do
      flush if @buf.size == @buf.max
      flush if (Time.now.to_f - @last_flush.to_f) > 0.5
      sleep(0.1)
    end
  end
	
  def self.flush
    payloads = []
    @mut.synchronize do
      @buf.size.times do
        payloads << @buf.deq
      end
    end
    return if payloads.nil? || payloads.empty?
    payloads.flatten.each do |payload|
      req = Net::HTTP::Post.new(LOGPLEX_URL.path)
      req.body = fmt(payload)
      @reqs.enq(req)
    end    
    @last_flush = Time.now
  end

  def self.fmt(data)
    pkt = "<190>1 "
    pkt += "#{data[:ts]} "
    pkt += "#{@hostname} "
    pkt += "#{data[:token]} "
    pkt += "lpxc "
    pkt += "- - "
    pkt += data[:msg]
    "#{pkt.size} #{pkt}".tap {|s| $stdout.puts(s)}
  end

  def self.outlet
    http = Net::HTTP.new(LOGPLEX_URL.host, LOGPLEX_URL.port)
    http.use_ssl = true
    http.start do |http|
      loop do
        req = @reqs.deq
        req['Content-Type'] = 'application/logplex-0'
        resp = http.request(req)
        $stdout.puts("at=request-sent status=#{resp.code}")
      end
    end
  end
end

Thread.new {Lpxc.start}
loop do
  Lpxc.puts("t.3990a976-874f-4b11-97c3-d2110b61672f", "time=#{Time.now.to_i}")
  sleep(1)
end
