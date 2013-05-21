#lpxc

A reference implementation of a ruby library that sends log data to Heroku's Logplex.

## Usage

```ruby
require 'lpxc'
Lpxc.Start
Lpxc.puts(logplex_token, "hello world")
```

## Test

Grab a logplex token from an Add-on provision request and pass it to test.rb

```ruby
$ ruby test.rb t.abc123
```
