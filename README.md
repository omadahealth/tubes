# Tubes

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/tubes`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

Proxy tube:
```
docker build -t tubes . && echo 'Starting' && docker run -v /var/run/docker.sock:/var/run/docker.sock -it -p 3000:3000 tubes
```

Sample Server:
```
docker run -l 'tubes.http.host=foo' -l 'tubes.http.port=5000' -it training/webapp:latest
```

Sample Client:
```
curl -x http://localhost:3000 http://foo.io/
```

```ruby
gem 'tubes'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tubes

## Usage

Simply run the `tubes` binary to start a proxy from localhost:3000 to localhost:80

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/tubes. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

