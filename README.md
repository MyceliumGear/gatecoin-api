# GatecoinAPI

This gem is a wrapper for [Gatecoin](https://www.gatecoin.com/) API.

[![Build Status](https://travis-ci.org/MyceliumGear/gatecoin-api.svg)](https://travis-ci.org/MyceliumGear/gatecoin-api)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'gatecoin-api'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install gatecoin-api

## Usage

    require 'gatecoin-api'
    client = GatecoinAPI::Client.new(
      public_key:  'public_key',
      private_key: 'api_key',
      url:         GatecoinAPI::PRODUCTION_URL,
    )

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MyceliumGear/gatecoin-api.
