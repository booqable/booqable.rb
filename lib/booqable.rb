# frozen_string_literal: true

# Dependencies
require "faraday"
require "faraday/retry"
require "json"
require "sawyer"
require "sawyer/link_parsers/simple"

# Internal
require_relative "booqable/version"
require_relative "booqable/rate_limit"
require_relative "booqable/error"
require_relative "booqable/oauth_client"
require_relative "booqable/middleware/base"
require_relative "booqable/middleware/raise_error"
require_relative "booqable/middleware/auth/oauth"
require_relative "booqable/middleware/auth/api_key"
require_relative "booqable/middleware/auth/single_use"
require_relative "booqable/resource_proxy"
require_relative "booqable/json_api_serializer"
require_relative "booqable/default"
require_relative "booqable/configurable"
require_relative "booqable/resources"
require_relative "booqable/auth"
require_relative "booqable/http"
require_relative "booqable/client"

# Main Booqable module providing access to the Booqable API
#
# @example Basic usage
#   Booqable.configure do |config|
#     config.api_key = "your_api_key"
#     config.company = "your_company"
#   end
#
#   orders = Booqable.orders.list(include: "customer,items")
#   orders.each do |order|
#     order.items.each do |item|
#       # Process each item in the order
#     end
#   end
#
module Booqable
  class << self
    include Booqable::Configurable

    # API client based on configured options {Configurable}
    #
    # @return [Booqable::Client] API wrapper
    def client
      return @client if defined?(@client) && @client.same_options?(options)

      @client = Booqable::Client.new(options)
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

Booqable.setup
