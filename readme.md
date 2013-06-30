#lpxc

Lpxc is a fast & efficient client for sending log messages to Heroku's logplex. It uses batching and keep-alive connections to enable high-throughput with little overhead.

## Documentation

[Rdoc](https://lpxc.s3.amazonaws.com/doc/Lpxc.html)

## Usage

```bash
$ gem install lpxc
```

```ruby
require 'lpxc'
lpxc = Lpxc.new
lpxc.puts("hello world", 't.123')
```

## Runing Tests

```bash
$ ruby test.rb
```
