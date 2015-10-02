require "litmus/instant/version"
require "httparty"

module Litmus
  module Instant
    include HTTParty

    base_uri "https://instant-api.litmus.com/v1"

    headers "Content-Type" => "application/json"
    headers "Accept"       => "application/json"

    def self.api_key(key)
      self.basic_auth key, ""
    end
    singleton_class.send(:alias_method, :api_key=, :api_key)

    def self.create_email(email)
      post "/emails", body: email.to_json
    end

    def self.clients
      get "/clients"
    end

    def self.get_preview(email_guid, client)
      get "/emails/#{email_guid}/previews/#{client}"
    end

    def self.prefetch_preview(email_guid, client)
      get "/emails/#{email_guid}/previews/#{client}?prefetch=true"
    end

    def self.prefetch_previews(email_guid, configurations)
      post "/emails/#{email_guid}/previews/prefetch", body: { configurations: configurations }.to_json
    end

    def self.preview_image_url(email_guid, client, image_type = "full")
      "#{sharded_base_uri(client)}/emails/#{email_guid}/previews/#{client}/#{image_type}"
    end

    # This avoids browser per domain connection limits
    def self.sharded_base_uri(client)
      base_uri.gsub("://","://#{client}.")
    end
  end
end
