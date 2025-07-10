# frozen_string_literal: true

module BQBL
  # Rate limit information from API responses
  #
  # Contains rate limiting information extracted from HTTP response headers.
  # This information is available when rate limit errors occur or can be
  # accessed from successful responses to monitor API usage.
  #
  # @example Accessing rate limit info from an error
  #   begin
  #     BQBL.orders.list
  #   rescue BQBL::TooManyRequests => e
  #     rate_limit = e.context
  #     puts "Rate limit: #{rate_limit.remaining}/#{rate_limit.limit}"
  #     puts "Resets in: #{rate_limit.resets_in} seconds"
  #   end
  #
  # @!attribute [w] limit
  #   @return [Integer] Max tries per rate limit period
  # @!attribute [w] remaining
  #   @return [Integer] Remaining tries per rate limit period
  # @!attribute [w] resets_in
  #   @return [Integer] Number of seconds when rate limit resets
  class RateLimit < Struct.new(:limit, :remaining, :resets_in)
    # Extract rate limit information from HTTP response
    #
    # Parses standard rate limit headers from the HTTP response and creates
    # a RateLimit object with the extracted information. Falls back to default
    # values if headers are missing.
    #
    # @param response [#headers, #response_headers] HTTP response object
    # @return [RateLimit] Rate limit information object
    #
    # @example
    #   rate_limit = BQBL::RateLimit.from_response(response)
    #   puts "#{rate_limit.remaining} requests remaining"
    def self.from_response(response)
      info = new
      headers = response.headers if response.respond_to?(:headers) && !response.headers.nil?
      headers ||= response.response_headers if response.respond_to?(:response_headers) && !response.response_headers.nil?
      if headers
        info.limit = (headers["X-RateLimit-Limit"] || 1).to_i
        info.remaining = (headers["X-RateLimit-Remaining"] || 1).to_i
        info.resets_in = (headers["X-RateLimit-Period"] || 1).to_i
      end

      info
    end
  end
end
