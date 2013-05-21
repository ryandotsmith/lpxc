$stdout.sync = true

require 'time'
require 'net/http'
require 'uri'
require 'thread'
require 'timeout'

module Lpxc
  #Require that the logplex url be set as an env var.
  #In most cases, the value should be: https://east.logplex.io/logs
  LOGPLEX_URL = URI(ENV["LOGPLEX_URL"])
  #Not realy used by logplex.
  @hostname = "myhost"
  #This will show up in the Heroku logs tail command as: app[lpxc]
  @procid = "lpxc"
  #The msgid is not used by logplex.
  @msgid = "- -"
  @mut = Mutex.new
  @buf = SizedQueue.new(300)
  @reqs = SizedQueue.new(300)
  #Initialize the last_flush to the 0 value for time.
  @last_flush = Time.at(0)

  #The interface to publish logs into the stream.
  #This function will set the log message to the current time in UTC.
  def self.puts(tok, msg)
    @buf.enq({ts: Time.now.utc.to_datetime.rfc3339.to_s, token: tok, msg: msg})
  end

  #This method must be called in order for the messages to be sent to Logplex.
  #This method also spawns a thread that allows the messages to be batched.
  #Messages are flushed from memory every 500ms or when we have 300 messages,
  #whichever comes first.
  def self.start
    Thread.new {outlet}
    Thread.new do
      loop do
        begin
          flush if @buf.size == @buf.max
          flush if (Time.now.to_f - @last_flush.to_f) > 0.5
          sleep(0.1)
        rescue => e
          $stderr.puts("at=start-error error=#{e.message}")
        end
      end
    end
  end

  private
	
  #Take a lock to read all of the buffered messages.
  #Once we have read the messages, we make 1 http request for the batch.
  #We pass the request off into the request queue so that the request
  #can be sent to LOGPLEX_URL.
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

  #Format the user message into rfc5425 format.
  #This method also prepends the length to the message.
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

  #We use a keep-alive connection to send data to LOGPLEX_URL.
  #Each request will contain one or more log messages.
  def self.outlet
    loop do
      begin
        Timeout::timeout(60) do
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
      rescue => e
        $stderr.puts("at=request-error error=#{e.message}")
      end
    end
  end
end
