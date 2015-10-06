require "litmus/instant/version"
require "httparty"
require "uri"
require "cgi"

module Litmus
  module Instant
    include HTTParty

    base_uri "https://instant-api.litmus.com/v1"

    headers "Content-Type" => "application/json"
    headers "Accept"       => "application/json"

    class << self
      attr_accessor :key

      # HTTParty doesn't favour exceptions, we do, so we wrap its methods to
      # give us what we want
      %i{get post patch put delete move copy head options}.each do |method|
        alias_method :"#{method}_without_raise", method

        define_method method do |*args|
          response = send(:"#{method}_without_raise", *args)
          raise_on_failure(response)
        end
      end
    end

    class BaseError < StandardError; end
    class RequestError < BaseError; end
    class AuthenticationError < BaseError; end
    class ServerError < BaseError; end
    class NotFound < BaseError; end

    def self.api_key(key=nil)
      if key
        @key = key
        self.basic_auth key, ""
      end
      @key
    end
    singleton_class.send(:alias_method, :api_key=, :api_key)

    def self.create_email(email)
      post("/emails", body: email.to_json)
    end

    def self.clients
      get "/clients"
    end

    def self.client_configurations
      get "/clients/configurations"
    end

    def self.get_preview(email_guid, client)
      get "/emails/#{email_guid}/previews/#{client}"
    end

    def self.prefetch_previews(email_guid, configurations)
      post "/emails/#{email_guid}/previews/prefetch", body: { configurations: configurations }.to_json
    end

    # We'd use Ruby 2.x keyword args here, but it's more useful to preserve
    # compatibility for anyone stuck with ruby < 2.x
    def self.preview_image_url(email_guid, client, capture_size = "full", options = {})
      if options.keys.length > 0
        if options[:fallback_url]
          options[:fallback_url] = CGI.escape(options[:fallback_url])
        end
        puts options.inspect
        query = URI.encode_www_form(options)
        "#{sharded_base_uri(client)}/emails/#{email_guid}/previews/#{client}/#{capture_size}?#{query}"
      else
        "#{sharded_base_uri(client)}/emails/#{email_guid}/previews/#{client}/#{capture_size}"
      end
    end

    private

    # This avoids browser per domain connection limits
    def self.sharded_base_uri(client)
      base_uri.gsub("://","://#{client}.")
    end

    def self.raise_on_failure(response)
      unless response.success?
        message = response["description"] || ""

        raise AuthenticationError.new(message) if response.code == 401
        raise RequestError.new(message) if response.code == 400
        raise NotFound.new(message) if response.code == 404
      end

      response
    end
  end
end
