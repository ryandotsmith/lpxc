$:.unshift('.')
require 'lpxc'
Lpxc.start
loop do
  Lpxc.puts(ARGV[0], 'hello world')
  sleep(0.5)
end
