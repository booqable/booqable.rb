module Booqable
  module Middleware
    module Auth
      # Faraday middleware for OAuth2 authentication
      #
      # This middleware handles OAuth2 token-based authentication for HTTP requests.
      # It automatically manages access tokens, refreshing them when expired, and
      # adds the Bearer token to the Authorization header.
      #
      # @example Adding to Faraday middleware stack
      #   builder.use Booqable::Middleware::Auth::OAuth,
      #     client_id: "your_client_id",
      #     client_secret: "your_client_secret",
      #     api_endpoint: "https://company.booqable.com/api/v4/oauth/token",
      #     read_token: -> { stored_token },
      #     write_token: ->(token) { store_token(token) }
      class OAuth < Base
        # Initialize the OAuth authentication middleware
        #
        # @param app [#call] The next middleware in the Faraday stack
        # @param options [Hash] Configuration options
        # @option options [String] :client_id OAuth client ID
        # @option options [String] :client_secret OAuth client secret
        # @option options [String] :api_endpoint API endpoint URL for the OAuth provider
        # @option options [Proc] :read_token Proc to read stored token
        # @option options [Proc] :write_token Proc to store new token
        # @raise [KeyError] If required options are not provided
        def initialize(app, options = {})
          super(app)

          @client_id = options.fetch(:client_id)
          @client_secret = options.fetch(:client_secret)
          @api_endpoint = options.fetch(:api_endpoint)
          @read_token = options.fetch(:read_token)
          @write_token = options.fetch(:write_token)

          @client = OAuthClient.new(
            client_id: @client_id,
            client_secret: @client_secret,
            api_endpoint: @api_endpoint,
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
          @token = @client.get_access_token_from_hash(@read_token.call)

          if @token.expired? || @token.expires_at.nil?
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
        # Booqable errors for consistent error handling.
        #
        # @return [OAuth2::AccessToken] The new access token
        # @raise [Booqable::Error] For OAuth-related errors
        def refresh_token!
          new_token = @token.refresh!

          @write_token.call(new_token.to_hash)

          new_token
        rescue OAuth2::Error => e
          response = e.response.response.env

          Booqable::Error.from_response(response)
        end
      end
    end
  end
end
