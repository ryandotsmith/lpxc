$stdout.sync = true

require 'time'
require 'net/http'
require 'uri'
require 'thread'

Thread.abort_on_exception = true

module Lpxc
  LOGPLEX_URL = URI(ENV["LOGPLEX_URL"])
  @hostname = "myhost"
  @procid = "lpxc"
  @msgid = "- -"
  @mut = Mutex.new
  @buf = SizedQueue.new(300)
  @reqs = SizedQueue.new(300)

  def self.puts(tok, msg)
    @buf.enq({ts: Time.now.utc.to_datetime.rfc3339.to_s, token: tok, msg: msg})
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
    body, tok = "", ""
    payloads.flatten.each do |payload|
      body += "#{fmt(payload) }"
      tok = payload[:token]
    end    
    req = Net::HTTP::Post.new(LOGPLEX_URL.path)
    req.basic_auth("token", tok)
    req.body = body
    @reqs.enq(req)
    @last_flush = Time.now
  end

  def self.fmt(data)
    pkt = "<190>1 "
    pkt += "#{data[:ts]} "
    pkt += "#{@hostname} "
    pkt += "#{data[:token]} "
    pkt += "#{@procid} "
    pkt += "#{@msgid} "
    pkt += data[:msg]
    "#{pkt.size} #{pkt}"
  end

  def self.outlet
    http = Net::HTTP.new(LOGPLEX_URL.host, LOGPLEX_URL.port)
    http.use_ssl = true
    http.start do |http|
      loop do
        req = @reqs.deq
        req.add_field('Content-Type', 'application/logplex-1')
        resp = http.request(req)
        $stdout.puts("at=request-sent status=#{resp.code}")
      end
    end
  end
end

Thread.new {Lpxc.start}
loop do
  Lpxc.puts("t.9821e525-3393-4576-9330-06a2ed3c121d", "time=#{Time.now.to_i}")
  sleep(1)
end
