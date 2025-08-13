
module Booqable
  # Default configuration options for {Client}
  #
  # Provides default values for all configuration options, with support for
  # environment variable overrides. All defaults can be overridden by setting
  # the appropriate environment variables.
  #
  # @example Environment variable configuration
  #   ENV["BOOQABLE_API_KEY"] = "your_api_key"
  #   ENV["BOOQABLE_COMPANY"] = "your_company"
  #   ENV["BOOQABLE_PER_PAGE"] = "50"
  module Default
    # Default User Agent header string
    USER_AGENT   = "Booqable Ruby Gem #{Booqable::VERSION}"

    # Default media type (json:api) for requests
    MEDIA_TYPE   = "application/vnd.api+json"

    # Default retry options for Faraday::Retry middleware
    RETRY_OPTIONS = {
      exceptions: Faraday::Retry::Middleware::DEFAULT_EXCEPTIONS + [ Booqable::ServerError ],
      max: 2, # maximum number of retries (total of 3 attempts including the first)
      interval: 2, # seconds to wait before retrying
      interval_randomness: 0.5, # randomize the interval by this amount
      backoff_factor: 2 # multiply the interval by this factor on each retry
    }

    # Basic middleware stack for Faraday::Connection (without authentication middleware)
    MIDDLEWARE = Faraday::RackBuilder.new do |builder|
      # Retry middleware
      builder.use Faraday::Retry::Middleware, RETRY_OPTIONS
      # Error handling middleware
      builder.use Booqable::Middleware::RaiseError

      builder.adapter Faraday.default_adapter
    end

    class << self
      # Configuration options
      # @return [Hash]
      def options
        Booqable::Configurable.keys.to_h { |key| [ key, send(key) ] }
      end

      # Default API endpoint from ENV
      # @return [String]
      def api_domain
        ENV.fetch("BOOQABLE_API_DOMAIN", "booqable.com")
      end

      # Default API version from ENV
      # @return [Integer] API version number
      def api_version
        ENV.fetch("BOOQABLE_API_VERSION", 4)
      end

      # Default API endpoint from ENV
      # @return [String, nil] Full API endpoint URL or nil to construct from domain
      def api_endpoint
        ENV.fetch("BOOQABLE_API_ENDPOINT", nil)
      end

      # Default pagination preference from ENV
      # @return [String]
      def auto_paginate
        ENV.fetch("BOOQABLE_AUTO_PAGINATE", nil)
      end

      # Default OAuth app key from ENV
      # @return [String]
      def client_id
        ENV.fetch("BOOQABLE_CLIENT_ID", nil)
      end

      # Default OAuth app secret from ENV
      # @return [String]
      def client_secret
        ENV.fetch("BOOQABLE_CLIENT_SECRET", nil)
      end

      # Default company from ENV
      # @return [String, nil] Company identifier/subdomain
      def company
        ENV.fetch("BOOQABLE_COMPANY", nil)
      end

      # Default redirect URI for OAuth from ENV
      # @return [String]
      def redirect_uri
        ENV.fetch("BOOQABLE_REDIRECT_URI", nil)
      end

      # Default options for Faraday::Connection
      # @return [Hash]
      def connection_options
        nil
      end

      # Default media type from ENV or {MEDIA_TYPE}
      # @return [String]
      def default_media_type
        ENV.fetch("BOOQABLE_DEFAULT_MEDIA_TYPE") { MEDIA_TYPE }
      end

      # Default middleware stack for Faraday::Connection
      # from {MIDDLEWARE}
      # @return [Faraday::RackBuilder or Faraday::Builder]
      def middleware
        MIDDLEWARE
      end

      # Default pagination page size from ENV
      # @return [Integer] Page size
      def per_page
        page_size = ENV.fetch("BOOQABLE_PER_PAGE", 25)

        page_size&.to_i
      end

      # Default proxy server URI for Faraday connection from ENV
      # @return [String]
      def proxy
        ENV.fetch("BOOQABLE_PROXY", nil)
      end

      # Default SSL verify mode from ENV
      # @return [Integer]
      def ssl_verify_mode
        # 0 is OpenSSL::SSL::VERIFY_NONE
        # 1 is OpenSSL::SSL::SSL_VERIFY_PEER
        # the standard default for SSL is SSL_VERIFY_PEER which requires a server certificate check on the client
        ENV.fetch("BOOQABLE_SSL_VERIFY_MODE", 1).to_i
      end

      # Default User-Agent header string from ENV or {USER_AGENT}
      # @return [String]
      def user_agent
        ENV.fetch("BOOQABLE_USER_AGENT") { USER_AGENT }
      end

      # Default OAuth token reader
      # @return [Proc] Empty proc that returns nothing
      def read_token
        Proc.new { }
      end

      # Default OAuth token writer
      # @return [Proc] Empty proc that does nothing
      def write_token
        Proc.new { }
      end

      # Default API key from ENV
      # @return [String, nil] API key for authentication
      def api_key
        ENV.fetch("BOOQABLE_API_KEY", nil)
      end

      # Default single use token from ENV
      # @return [String, nil] Single use token for authentication
      def single_use_token
        ENV.fetch("BOOQABLE_SINGLE_USE_TOKEN", nil)
      end

      # Default single use token algorithm from ENV
      # @return [String, nil] Algorithm for single use token (e.g., "HS256", "RS256")
      def single_use_token_algorithm
        ENV.fetch("BOOQABLE_SINGLE_USE_TOKEN_ALGORITHM", nil)
      end

      # Default single use token secret from ENV
      # @return [String, nil] Secret for HMAC single use token signing
      def single_use_token_secret
        ENV.fetch("BOOQABLE_SINGLE_USE_TOKEN_SECRET", nil)
      end

      # Default single use token private key from ENV
      # @return [String, nil] Private key for RSA/ECDSA single use token signing
      def single_use_token_private_key
        ENV.fetch("BOOQABLE_SINGLE_USE_TOKEN_PRIVATE_KEY", nil)
      end

      # Default single use token expiration period from ENV
      # @return [Integer] Token expiration period in seconds
      def single_use_token_expiration_period
        ENV.fetch("BOOQABLE_SINGLE_USE_TOKEN_EXPIRATION_PERIOD") { 10 * 60 }.to_i # default to 10 minutes
      end

      # Default single use token company ID from ENV
      # @return [String, nil] Company ID for single use token
      def single_use_token_company_id
        ENV.fetch("BOOQABLE_SINGLE_USE_TOKEN_COMPANY_ID", nil)
      end

      # Default single use token user ID from ENV
      # @return [String, nil] User ID for single use token
      def single_use_token_user_id
        ENV.fetch("BOOQABLE_SINGLE_USE_TOKEN_USER_ID", nil)
      end

      # Default debug mode setting
      # @return [Boolean] Whether debug mode is enabled
      def debug
        false
      end

      # Default retry setting
      # @return [Boolean] Whether to disable retries
      def no_retries
        false
      end
    end
  end
end
