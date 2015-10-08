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

    class ApiError < StandardError; end
    class RequestError < ApiError; end
    class AuthenticationError < ApiError; end
    class ServiceError < ApiError; end
    class TimeoutError < ApiError; end
    class NotFound < ApiError; end


    # Get or set your Instant API key
    # @return [String]
    def self.api_key(key=nil)
      if key
        @key = key
        self.basic_auth key, ""
      end
      @key
    end
    singleton_class.send(:alias_method, :api_key=, :api_key)

    # Describe an email’s content and metadata and, in exchange, receive an
    # +email_guid+ required to capture previews of it
    #
    # We intend these objects to be treated as lightweight. Once uploaded,
    # emails can't be modified. Obtain a new +email_guid+ each time changes need
    # to be reflected.
    #
    # The uploaded email has a limited lifespan. As a result, a new +email_guid+
    # should be obtained before requesting new previews if more than a day has
    # passed since the last upload.
    #
    # At least one of +:html_text+, +:plain_text+, +:raw_source+ must be
    # provided.
    #
    # @param [Hash] email
    # @option email [String] :html_text
    # @option email [String] :plain_text
    # @option email [String] :subject
    # @option email [String] :from_address
    # @option email [String] :from_display_name
    # @option email [String] :raw_source
    #   This field provides an alternative approach to defining the email and
    #   so is only valid in the absence of all the fields above
    # @option email [String] :end_user_id A unique identifier for your end
    #   users. When provided, we use this to partition your usage data.
    #   See https://litmus.com/partners/api/documentation/instant/03-identifying-end-users/
    # @option email [Array<Hash>]  :configurations
    #   An array of capture capture configuration hashes
    #   This allows pre-requesting previews that should be captured as soon as
    #   possible. This can be a useful performance optimisation.
    #   See +.prefetch_previews+ for further detail on format.
    #
    # @return [Hash] the response containing the +email_guid+ and also
    #   confirmation of +end_user_id+ and +configurations+ if provided
    def self.create_email(email)
      post("/emails", body: email.to_json)
    end

    # List supported email clients
    # @return [Array<String>] array of email client names
    def self.clients
      get "/clients"
    end

    # List supported email client configurations
    # @return [Hash] hash keyed by email client name, values are a Hash with the
    #   the keys +orientation_options+ and +images_options+
    def self.client_configurations
      get "/clients/configurations"
    end

    # Request a preview
    #
    # This triggers the capture of a preview. The method blocks until capture
    # completes. The response contains URLs for each of the image sizes
    # available. A further request will be needed to obtain actual image data
    # from one of the provided URLs.
    #
    # @param email_guid [String]
    # @param client [String]
    # @param options [Hash]
    # @option options [String] :images +allowed+ (default) or +blocked+
    # @option options [String] :orientation +horizontal+ or +vertical+ (default)
    #
    # @return [Hash] a hash mapping the available capture sizes to their
    #   corresponding URLs
    def self.get_preview(email_guid, client, options = {})
      query = URI.encode_www_form(options)
      get "/emails/#{email_guid}/previews/#{client}?#{query}"
    end

    # Pre-request a set of previews before download
    #
    # This method is provided as an optional performance enhancement, typically
    # useful before embedding a set of previews within a browser, where
    # connection limits might otherwise delay the start of capture of some
    # previews.
    #
    # The method does not block while capture occurs, a response is returned
    # immediately.
    #
    # Note that should capture failure occur for a preview, it will only be
    # discovered when the preview is later requested. Request errors, for
    # instance attempting to prefetch an invalid client, will result raise
    # normally howver.
    #
    # @param email_guid [String]
    # @param configurations [Array<Hash>]An array of capture capture configurations
    #   Each configuration Hash must have a +:client+ key, and optional
    #   +:orientation+ and +images+ keys
    #
    # @return [Hash] confirmation of the configurations being captured
    def self.prefetch_previews(email_guid, configurations)
      post "/emails/#{email_guid}/previews/prefetch", body: { configurations: configurations }.to_json
    end

    # Construct a preview image URL ready for download
    #
    # This does not make a call against the API.
    #
    # The generated URLs can be embedded directly within a client application,
    # for instance with the +src+ tag of an HTML +img+ tag.
    #
    # This is also useful for downloading a capture in a single step, rather
    # than calling +.get_preview+ then making a follow up request to retrieve
    # the image data.
    #
    # @param [String] email_guid
    # @param [String] client
    # @param [Hash] options
    # @option options [String] :capture_size +full+ (default), +thumb+ or +thumb450+
    # @option options [String] :images +allowed+ (default) or +blocked+
    # @option options [String] :orientation +horizontal+ or +vertical+ (default)
    # @option options [Boolean] :fallback by default errors during capture
    #   redirect to a fallback image, setting this to +false+ will mean that
    #   GETs to the resulting URL will receive HTTP error responses instead
    # @option options [String] :fallback_url a custom fallback image to display
    #   in case of errors. This must be an absolute URL and have a recognizable
    #   image extension. Query parameters are not supported. The image should be
    #   accessible publicly without the need for authentication.
    #
    # @return [String] the preview URL, domain sharded by the client name
    def self.preview_image_url(email_guid, client, options = {})
      # We'd use Ruby 2.x keyword args here, but it's more useful to preserve
      # compatibility for anyone stuck with ruby < 2.x
      capture_size = options.delete(:capture_size) || "full"

      if options.keys.length > 0
        if options[:fallback_url]
          options[:fallback_url] = CGI.escape(options[:fallback_url])
        end
        query = URI.encode_www_form(options)
        "#{sharded_base_uri(client)}/emails/#{email_guid}/previews/#{client}/#{capture_size}?#{query}"
      else
        "#{sharded_base_uri(client)}/emails/#{email_guid}/previews/#{client}/#{capture_size}"
      end
    end

    # Convenience for downloading raw image data in Ruby.
    #
    # In most situations it will be preferable to avoid this and instead
    # pass a URL for your client application to download.
    # @see Litmus::Instant.preview_image_url
    #
    # Under the hood this uses HTTParty/Net::HTTP, it's useful for small volumes
    # and one off image downloads, but not a good choice for downloading large
    # batches of captures, particularly with the blocking that will occur.
    # For full size captures an approach that streams and avoids loading the
    # whole image in to memory may be preferable.
    #
    # See the README for alternative approaches and recommendations.
    #
    # @param [String] email_guid
    # @param [String] client
    # @param [Hash] options
    # @option options [String] :capture_size +full+ (default), +thumb+ or +thumb450+
    # @option options [String] :images +allowed+ (default) or +blocked+
    # @option options [String] :orientation +horizontal+ or +vertical+ (default)
    # @option options [Boolean] :fallback by default errors during capture
    #   will raise, setting this to +true+ will mean that failures will be
    #   swallowed and the returned image data reflect the fallback image
    # @option options [String] :fallback_url a custom fallback image to display
    #   in case of errors. This must be an absolute URL and have a recognizable
    #   image extension. Query parameters are not supported. The image should be
    #   accessible publicly without the need for authentication.
    #
    # @return [HTTParty::Response] the parsed_response property of the returned
    #   object is the raw image data
    def self.get_preview_image(email_guid, client, options = {})
      options = { fallback: false }.merge(options)
      response = HTTParty.get(preview_image_url(email_guid, client, options))
      raise_on_failure(response)
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
        raise TimeoutError.new(message) if response.code == 504
        raise ServiceError.new(message) if response.code == 500

        # For all other errors
        raise ApiError.new(message)
      end

      response
    end
  end
end
