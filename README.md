# Litmus Instant API Ruby

A ruby API client library for interacting with [Litmus Instant API](https://litmus.com/partners/api/documentation/instant/01-getting-started/) - the fastest way to include email previews from real clients in your application.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "litmus-instant"
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install litmus-instant

## Usage

Require the library and set your Instant API key

```ruby
require "litmus/instant"
Litmus::Instant.api_key = "<YOUR INSTANT API KEY>"
```

Prepare an email for capture

```ruby
email_guid = Litmus::Instant.create_email(
  plain_text: "Aloha World!"
)["email_guid"]
# => "755d1f9f-ad28-460f-8e45-632e0eceab32"
```

Construct a preview URL for embedding client side or for downloading

```ruby
@preview_url = Litmus::Instant.preview_image_url(email_guid, "OL2010")
# => "https://OL2010.instant-api.litmus.com/v1/emails/755d1f9f-ad28-460f-8e45-632e0eceab32/previews/OL2010/full"
```

This could be used in a Rails erb template like so

```html
<%= image_tag @preview_url %>
```

### Performance

In the example above the capture wouldn't be initiated until the end user's browser made the HTTP GET request to the preview URL. This would mean waiting the full capture time (a number of seconds) before the image data began to transfer.

Valuable time can be shaved here by pre-requesting required capture configurations as early as it's known they're needed. By the time the browser comes to request the preview the capture will be in progress or completed, so transfer of the image data will begin sooner. This also avoids browser connection limits delaying the initiation of capture for previews queued behind other requests.

This pre-request can be provided during email creation

```ruby
Litmus::Instant.create_email(
  plain_text: "Aloha World!",
  configurations: [
    { client: "OL2010" },
    { client: "OL2013", images: "blocked" }
  ]
)
# => {"email_guid"=>"99e313eb-5256-4824-b26f-2f9e031fa8b5",
#     "configurations"=>
#       [{"orientation"=>"vertical", "images"=>"allowed", "client"=>"OL2010"},
#        {"orientation"=>"vertical", "images"=>"blocked", "client"=>"OL2013"}]}
```

or via the dedicated method

```ruby
Litmus::Instant.prefetch_previews(
  email_guid, [
    { client: "OL2010" },
    { client: "OL2013", images: "blocked" }
  ]
)
# => {"configurations"=>
#     [{"orientation"=>"vertical", "images"=>"allowed", "client"=>"OL2010"},
#      {"orientation"=>"vertical", "images"=>"blocked", "client"=>"OL2013"}]}
```

For further information see the [performance section](https://litmus.com/partners/api/documentation/instant/04-performance/) of the Instant API documentation.

### Handling errors

Various errors may occur can occur during normal usage of the API, please code defensively to handle these.

```ruby
begin
  # make Litmus::Instant api call
rescue Litmus::Instant::AuthenticationError => e
  # eg an invalid API key, or API key not set
rescue Litmus::Instant::RequestError => e
  # eg an invalid client configuration was requested
rescue Litmus::Instant::NotFound => e
  # The most likely cause of this is an invalid email_guid, or expired email
rescue Litmus::Instant::TimeoutError => e
  # An email client may timeout for various reasons, including upstream service
  # issues for webmail clients, or unexpected behaviour with problematic email
  # source
rescue Litmus::Instant::ServiceError => e
  # eg a capacity issue or unexpected infrastracture issue
  # This should occur extremely rarely
rescue Litmus::Instant::ApiError => e
  # API base error class, catch all the above and any other failure responses
rescue => e
  # Un unexpected error occurred, perhaps unrelated to the gem/API
end
```

Note that the default behaviour of the the embedable URL returned from `Litmus::Instant.preview_image_url` is to redirect to a fallback image if an error occurs during capture. This behavior can be overriden to raise errors by setting the `fallback` option to `false`.

### Downloading previews server-side

The gem itself provides `Litmus::Instant.get_preview_image` as a simple, if naïve, method for downloading the raw image data to an object in memory. This method is fine for incidental usage, but provides no opportunity for parallelisation or streaming straight to disk.

In the simplest case, downloading a single preview to a tempfile can be achieved with Ruby's [OpenURI](http://ruby-doc.org/stdlib-2.1.0/libdoc/open-uri/rdoc/OpenURI.html)

```ruby
require "open-uri"
open @preview_url
# ...blocks for a few seconds...
# => #<File:/var/folders/st/813n6d9d0ts_hj8ktmx0p0hh0000gn/T/open-uri20151007-51192-k3a53m>
```

A common use case is downloading a batch of previews for a selection of email clients. Often doing this as fast as possible is important for the desired experience in a waiting client application.

In this situation we recommend:

 - pre-requesting known clients before download
 - making parallel HTTP requests, with concurrency tuned to minimise wait time, maximise bandwidth usage, but minimise network contention issues.

When constrained by bandwidth, simply pre-requesting and then sequentially downloading one preview after another may yield the fastest completion time. In most situations, exceeding 15 concurrent connections is unlikely to improve overall completion time.

For managing parallel downloads in ruby, you could use multiple threads and Net:HTTP, em-http-request, or shell out to `wget` or `aria2`, however our example below uses [Typhoeus](https://github.com/typhoeus/typhoeus) which wraps libcurl.

```ruby
require "typhoeus"

# prerequest capture on all clients in their default configuration
clients = Litmus::Instant.clients
configurations = clients.map { |client| { client: client } }
Litmus::Instant.prefetch_previews(email_guid, configurations)

hydra = Typhoeus::Hydra.new(max_concurrency: 15)
clients.each do |client|
  preview_url = Litmus::Instant.preview_image_url(email_guid, client, capture_size: "thumb")
  request = Typhoeus::Request.new(preview_url, followlocation: true)
  request.on_complete do |response|
    File.write("/tmp/#{email_guid}-#{client}.png", response.body)
  end
  hydra.queue(request)
end
hydra.run

```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, with the `API_KEY` environment variable set appropriately, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/litmus/instant-api-ruby.


## License

© 2015 Litmus Software

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

