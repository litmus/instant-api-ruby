require "httparty/response"
require "litmus/core_ext/hash/deep_symbolize_keys"

module Litmus
  module Instant
    class Response < HTTParty::Response
      def initialize(httparty_response)
        @request      = httparty_response.request
        @response     = httparty_response.response
        @body         = httparty_response.response.body
        @headers      = httparty_response.headers

        @parsed_response_unsymbolized = httparty_response.parsed_response
      end

      def parsed_response
        @parsed_response ||= symbolize_keys(@parsed_response_unsymbolized)
      end

      private

      def symbolize_keys(parsed)
        case parsed
        when ::Array
          parsed.map { |child| child.is_a?(::Hash) ? child.deep_symbolize_keys : child }
        when ::Hash
          parsed.deep_symbolize_keys
        else
          parsed
        end
      end
    end
  end
end
