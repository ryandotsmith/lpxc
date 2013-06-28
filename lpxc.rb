$stdout.sync = true

require 'time'
require 'net/http'
require 'uri'
require 'thread'
require 'timeout'

class Lpxc

  attr_reader :reqs, :hash, :flush_interval
  def initialize(opts={})
    @hash = opts[:hash] || Hash.new
    @reqs = opts[:request_queue] || SizedQueue.new(300)
    @hash_lock = Mutex.new

    #Ignored by logplex
    @structured_data = opts[:structured_data] || "-"

    #Ignored by logplex
    @msgid = opts[:msgid] || "-"

    #This will show up in the Heroku logs tail command as: app[lpxc]
    @procid = opts[:procid] || "lpxc"

    #Ignored by logplex.
    @hostname = opts[:hostname] || "myhost"

    #Determines how long to keep the tcp connection to logplex alive.
    @conn_timeout = opts[:conn_timeout] || 60

    #Number of factional seconds to batch messages in memory.
    @flush_interval = opts[:flush_interval] || 0.5

    #In most cases, the value should be: https://east.logplex.io/logs
    err = "Must set logplex url."
    @logplex_url = URI(opts[:logplex_url] || ENV["LOGPLEX_URL"] || raise(err))
  end

  #The interface to publish logs into the stream.
  #This function will set the log message to the current time in UTC.
  def puts(msg, tok=nil)
    @hash_lock.synchronize do
      q = @hash[tok] ||= SizedQueue.new(300)
      q.enq({t: Time.now.utc, token: tok, msg: msg})
    end
  end

  #This method must be called in order for the messages to be sent to Logplex.
  #This method also spawns a thread that allows the messages to be batched.
  #Messages are flushed from memory every 500ms or when we have 300 messages,
  #whichever comes first.
  def start
    Thread.new {outlet}
    Thread.new do
      loop do
        begin
          #If any of the queues are full, we will flush the entire hash.
          flush if any_full?
          #If it has been 500ms since our last flush, we will flush.
          flush if (Time.now.to_f - @last_flush.to_f) > @flush_interval
          sleep(0.1)
        rescue => e
          $stderr.puts("at=start-error error=#{e.message}")
        end
      end
    end
  end

  #private
  
  def any_full?
    @hash_lock.synchronize do
      @hash.any? {|k,v| v.size == v.max}
    end
  end
	
  #Take a lock to read all of the buffered messages.
  #Once we have read the messages, we make 1 http request for the batch.
  #We pass the request off into the request queue so that the request
  #can be sent to LOGPLEX_URL.
  def flush
    @hash_lock.synchronize do
      @hash.each do |tok, msgs|
        #Copy the messages from the queue into the payload array.
        payloads = []
        msgs.size.times {payloads << msgs.deq}
        return if payloads.nil? || payloads.empty?

        #Use the payloads array to build a string that will be 
        #used as the http body for the logplex request.
        body = ""
        payloads.flatten.each do |payload|
          body += "#{fmt(payload)}"
        end    

        #Build a new HTTP request and place it into the queue
        #to be processed by the HTTP connection.
        req = Net::HTTP::Post.new(@logplex_url.path)
        req.basic_auth("token", tok)
        req.body = body
        @reqs.enq(req)
        @hash.delete(tok)
      end
      @last_flush = Time.now
    end
  end

  #Format the user message into RFC5425 format.
  #This method also prepends the length to the message.
  def fmt(data)
    pkt = "<190>1 "
    pkt += "#{data[:t].strftime("%Y-%m-%dT%H:%M:%S+00:00")} "
    pkt += "#{@hostname} "
    pkt += "#{data[:token]} "
    pkt += "#{@procid} "
    pkt += "#{@msgid} "
    pkt += "#{@structured_data} "
    pkt += data[:msg]
    "#{pkt.size} #{pkt}"
  end

  #We use a keep-alive connection to send data to LOGPLEX_URL.
  #Each request will contain one or more log messages.
  def outlet
    loop do
      begin
        Timeout::timeout(@conn_timeout) do
          http = Net::HTTP.new(@logplex_url.host, @logplex_url.port)
          http.set_debug_output($stdout) if ENV['DEBUG']
          http.use_ssl = true if @logplex_url.scheme == 'https'
          http.start do |conn|
            loop do
              #We will block here waiting for a request.
              req = @reqs.deq
              req.add_field('Content-Type', 'application/logplex-1')
              resp = conn.request(req)
              $stdout.puts("at=req-sent status=#{resp.code}") if ENV['DEBUG']
            end
          end
        end
      rescue => e
        $stderr.puts("at=request-error error=#{e.message}")
      end
    end
  end
end
