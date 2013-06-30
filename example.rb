require './lpxc'

client = Lpxc.new(
  :logplex_url=> 'https://east.logplex.io/logs',
  :default_token => ARGV[0]
)
4.times do
  client.puts('hello world')
end
client.wait
