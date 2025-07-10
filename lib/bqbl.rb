# frozen_string_literal: true

# Dependencies
require "faraday"
require "faraday/retry"
require "json"
require "sawyer"
require "sawyer/link_parsers/simple"

# Internal
require_relative "bqbl/version"
require_relative "bqbl/rate_limit"
require_relative "bqbl/error"
require_relative "bqbl/oauth_client"
require_relative "bqbl/middleware/base"
require_relative "bqbl/middleware/raise_error"
require_relative "bqbl/middleware/auth/oauth"
require_relative "bqbl/middleware/auth/api_key"
require_relative "bqbl/middleware/auth/single_use"
require_relative "bqbl/resource_proxy"
require_relative "bqbl/json_api_serializer"
require_relative "bqbl/default"
require_relative "bqbl/configurable"
require_relative "bqbl/resources"
require_relative "bqbl/auth"
require_relative "bqbl/http"
require_relative "bqbl/client"

# Main BQBL module providing access to the Booqable API
#
# @example Basic usage
#   BQBL.configure do |config|
#     config.api_key = "your_api_key"
#     config.company = "your_company"
#   end
#
#   orders = BQBL.orders.list(include: "customer,items")
#   orders.each do |order|
#     order.items.each do |item|
#       # Process each item in the order
#     end
#   end
#
module BQBL
  class << self
    include BQBL::Configurable

    # API client based on configured options {Configurable}
    #
    # @return [BQBL::Client] API wrapper
    def client
      return @client if defined?(@client) && @client.same_options?(options)

      @client = BQBL::Client.new(options)
    end

    private

    # Delegates respond_to? calls to the client
    #
    # @param method_name [Symbol] the method name to check
    # @param include_private [Boolean] whether to include private methods
    # @return [Boolean] true if the client responds to the method
    def respond_to_missing?(method_name, include_private = false)
      client.respond_to?(method_name, include_private)
    end

    # Delegates method calls to the client when the client responds to them
    #
    # @param method_name [Symbol] the method name being called
    # @param args [Array] arguments passed to the method
    # @param block [Proc] block passed to the method
    # @return [Object] the result of calling the method on the client
    # @raise [NoMethodError] when neither the module nor client respond to the method
    def method_missing(method_name, *args, &block)
      if client.respond_to?(method_name)
        return client.send(method_name, *args, &block)
      end

      super
    end
  end
end

BQBL.setup
