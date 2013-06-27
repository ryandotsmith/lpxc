#lpxc

A simple ruby client to help send log messages to Heroku's logplex.

## Usage

```ruby
require 'lpxc'
lpxc = Lpxc.new
lpxc.puts("hello world", 't.123')
```

## Runing Tests

```bash
$ ruby test.rb
```
