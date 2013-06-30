#lpxc

Lpxc is designed to be an fast & efficient client for sending data to Heroku's logplex. It uses batching and keep-alive connection to enable high-throughput at little cost to your program.

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
