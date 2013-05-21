#lpxc

A reference implementation of a ruby library that sends log data to Heroku's Logplex.

## Usage

```ruby
require 'lpxc'
Lpxc.Start
Lpxc.puts(logplex_token, "hello world")
```
