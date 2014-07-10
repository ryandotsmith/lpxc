#lpxc

Lpxc is a fast & efficient client for sending log messages to Heroku's logplex. It uses batching and keep-alive connections to enable high-throughput with little overhead.

## Dependencies
All dependencies come from the standard library. The following version of Ruby are supported:

* 1.9.3
* 2.0.0
* 2.1.0

## Documentation

[Rdoc](http://rubydoc.info/github/ryandotsmith/lpxc/master/Lpxc)

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
[![Build Status](https://travis-ci.org/ryandotsmith/lpxc.png?branch=master)](https://travis-ci.org/ryandotsmith/lpxc)

```bash
$ ruby test.rb
```
