# frozen_string_literal: true

module Booqable
  # Configuration options for {Client}, defaulting to values
  # in {Default}
  module Configurable
    # @!attribute api_endpoint
    #   @return [String] Base URL for API requests. default: https://company.booqable.com/api/4
    # @!attribute auto_paginate
    #   @return [Boolean] Auto fetch next page of results until rate limit reached
    # @!attribute client_id
    #   @return [String] Configure OAuth app key
    # @!attribute [w] client_secret
    #   @return [String] Configure OAuth app secret
    # @!attribute default_media_type
    #   @return [String] Configure preferred media type (for API versioning, for example)
    # @!attribute connection_options
    #   @see https://github.com/lostisland/faraday
    #   @return [Hash] Configure connection options for Faraday
    # @!attribute middleware
    #   @see https://github.com/lostisland/faraday
    #   @return [Faraday::Builder or Faraday::RackBuilder] Configure middleware for Faraday
    # @!attribute per_page
    #   @return [String] Configure page size for paginated results. API default: 25
    # @!attribute proxy
    #   @see https://github.com/lostisland/faraday
    #   @return [String] URI for proxy server
    # @!attribute ssl_verify_mode
    #   @see https://github.com/lostisland/faraday
    #   @return [String] SSL verify mode for ssl connections
    # @!attribute user_agent
    #   @return [String] Configure User-Agent header for requests.

    attr_accessor :api_domain,
                  :api_endpoint,
                  :api_key,
                  :api_version,
                  :auto_paginate,
                  :client_id,
                  :client_secret,
                  :company,
                  :connection_options,
                  :debug,
                  :default_media_type,
                  :middleware,
                  :no_retries,
                  :per_page,
                  :proxy,
                  :read_token,
                  :redirect_uri,
                  :single_use_token,
                  :single_use_token_algorithm,
                  :single_use_token_company_id,
                  :single_use_token_expiration_period,
                  :single_use_token_private_key,
                  :single_use_token_secret,
                  :single_use_token_user_id,
                  :ssl_verify_mode,
                  :user_agent,
                  :write_token

    class << self
      # List of configurable keys for {Booqable::Client}
      # @return [Array] of option keys
      def keys
        @keys ||= %i[
          api_domain
          api_endpoint
          api_key
          api_version
          auto_paginate
          client_id
          client_secret
          company
          connection_options
          debug
          default_media_type
          middleware
          no_retries
          per_page
          proxy
          read_token
          redirect_uri
          single_use_token
          single_use_token_algorithm
          single_use_token_company_id
          single_use_token_expiration_period
          single_use_token_private_key
          single_use_token_secret
          single_use_token_user_id
          ssl_verify_mode
          user_agent
          write_token
        ]
      end
    end

    # Set configuration options using a block
    def configure
      yield self
    end

    # Reset configuration options to default values
    def reset!
      # rubocop:disable Style/HashEachMethods
      #
      # This may look like a `.keys.each` which should be replaced with `#each_key`, but
      # this doesn't actually work, since `#keys` is just a method we've defined ourselves.
      # The class doesn't fulfill the whole `Enumerable` contract.
      Booqable::Configurable.keys.each do |key|
        # rubocop:enable Style/HashEachMethods
        instance_variable_set(:"@#{key}", Booqable::Default.options[key])
      end
      self
    end
    alias setup reset!

    # Compares client options to a Hash of requested options
    #
    # @param opts [Hash] Options to compare with current client options
    # @return [Boolean]
    def same_options?(opts)
      opts.hash == options.hash
    end

    # Whether to print debug information
    #
    # @return [Boolean] true if debug mode is enabled, false otherwise
    def debug?
      @debug || false
    end

    private

    def api_protocol
      @api_domain == "booqable.com" ? "https" : "http"
    end

    def options
      Booqable::Configurable.keys.to_h { |key| [ key, instance_variable_get(:"@#{key}") ] }
    end
  end
end
