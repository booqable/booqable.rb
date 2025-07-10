module BQBL
  module Middleware
    module Auth
      # Faraday middleware for OAuth2 authentication
      #
      # This middleware handles OAuth2 token-based authentication for HTTP requests.
      # It automatically manages access tokens, refreshing them when expired, and
      # adds the Bearer token to the Authorization header.
      #
      # @example Adding to Faraday middleware stack
      #   builder.use BQBL::Middleware::Auth::OAuth,
      #     client_id: "your_client_id",
      #     client_secret: "your_client_secret",
      #     base_url: "https://company.booqable.com",
      #     read_token: -> { stored_token },
      #     write_token: ->(token) { store_token(token) }
      class OAuth < Base
        # Default OAuth token endpoint
        TOKEN_ENDPOINT = "/api/boomerang/oauth/token"

        # Initialize the OAuth authentication middleware
        #
        # @param app [#call] The next middleware in the Faraday stack
        # @param options [Hash] Configuration options
        # @option options [String] :client_id OAuth client ID
        # @option options [String] :client_secret OAuth client secret
        # @option options [String] :base_url Base URL for the OAuth provider
        # @option options [String] :token_url Token endpoint URL (defaults to TOKEN_ENDPOINT)
        # @option options [Proc] :read_token Proc to read stored token
        # @option options [Proc] :write_token Proc to store new token
        # @raise [KeyError] If required options are not provided
        def initialize(app, options = {})
          super(app)

          @client_id = options.fetch(:client_id)
          @client_secret = options.fetch(:client_secret)
          @base_url = options.fetch(:base_url)
          @token_url = options.fetch(:token_url, TOKEN_ENDPOINT)
          @read_token = options.fetch(:read_token)
          @write_token = options.fetch(:write_token)

          @client = OAuth2::Client.new(
            @client_id,
            @client_secret,
            site: @base_url,
            token_url: @token_url
          )
        end

        # Process the HTTP request and add OAuth authentication
        #
        # Retrieves the stored access token, refreshes it if expired, and adds
        # it to the Authorization header. Then passes the request to the next
        # middleware in the stack.
        #
        # @param env [Faraday::Env] The request environment
        # @return [Faraday::Response] The response from the next middleware
        def call(env)
          @token = OAuth2::AccessToken.from_hash(@client, @read_token.call)

          if @token.expired?
            @token = refresh_token!
          end

          env.request_headers["Authorization"] ||= "Bearer #{@token.token}"

          @app.call(env)
        end

        private

        # Refresh the expired OAuth token
        #
        # Uses the refresh token to obtain a new access token and stores it
        # using the configured write_token proc. Converts OAuth2 errors to
        # BQBL errors for consistent error handling.
        #
        # @return [OAuth2::AccessToken] The new access token
        # @raise [BQBL::Error] For OAuth-related errors
        def refresh_token!
          new_token = @token.refresh!

          @write_token.call(new_token.to_hash)

          new_token
        rescue OAuth2::Error => e
          response = e.response.response.env.to_h

          BQBL::Error.from_response(response)
        end
      end
    end
  end
end
