#lpxc

Lpxc is a fast & efficient client for sending log messages to Heroku's logplex. It uses batching and keep-alive connections to enable high-throughput with little overhead.

## Documentation

[Rdoc](http://rubydoc.info/github/ryandotsmith/lpxc/master/Lpxc)

## Usage

```bash
$ gem install lpxc
```

Specifying a logplex token.
```ruby
ENV['LOGPLEX_URL'] = 'https://east.logplex.io/logs'
require 'lpxc'
lpxc = Lpxc.new
lpxc.puts("hello world", 't.123')
```
Relying on the token set in the `$LOGPLEX_URL`.
```ruby
ENV['LOGPLEX_URL'] = 'https://t.123@east.logplex.io/logs'
require 'lpxc'
lpxc = Lpxc.new
lpxc.puts("hello world")
```

## Runing Tests

[![Build Status](https://drone.io/github.com/ryandotsmith/lpxc/status.png)](https://drone.io/github.com/ryandotsmith/lpxc/latest)

```bash
$ ruby test.rb
```
