$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "litmus/instant"
require "webmock/rspec"
require "vcr"
require "logger"

Dir["./spec/support/**/*.rb"].each { |f| require f }

abort "API_KEY required" unless ENV["API_KEY"]

VCR.configure do |config|
  config.cassette_library_dir = "fixtures/vcr_cassettes"
  config.hook_into :webmock

  config.filter_sensitive_data('<API_KEY>') { ENV['API_KEY'] }

  #config.debug_logger = $stderr
end

RSpec.configure do |config|
  # default: unauthenticated
  config.before :each, authenticated: true do
    Litmus::Instant.api_key = ENV["API_KEY"]
  end
  config.after :each, authenticated: true do
    Litmus::Instant.default_options.delete :basic_auth
  end

  # Add VCR to all tests
  config.around(:each) do |example|
    default_options = { record: :new_episodes }
    options = default_options.merge(example.metadata[:vcr] || {})
    if options[:record] == :skip
      VCR.turned_off(&example)
    else
      name = example.metadata[:full_description].
                     split(/\s+/, 2).
                     join('/').
                     gsub(/\./,'/').
                     gsub(/[^\w\/]+/, '_').
                     gsub(/\/$/, '')
      VCR.use_cassette(name, options, &example)
    end
  end
end
