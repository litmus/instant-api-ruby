def with_authentication
  Litmus::Instant.api_key = ENV["API_KEY"]
  result = yield
  Litmus::Instant.default_options.delete :basic_auth
  result
end
