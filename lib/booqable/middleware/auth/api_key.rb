module Booqable
  module Middleware
    module Auth
      # Faraday middleware for API key authentication
      #
      # This middleware adds Bearer token authentication to HTTP requests using
      # a pre-configured API key. The API key is added to the Authorization header
      # for each request unless already present.
      #
      # For more info see: https://developers.booqable.com/#authentication-access-token
      #
      # @example Adding to Faraday middleware stack
      #   builder.use Booqable::Middleware::Auth::ApiKey, api_key: "your_api_key"
      class ApiKey < Base
        # OAuth token endpoint (legacy reference)
        TOKEN_ENDPOINT = "/api/boomerang/oauth/token"

        # Initialize the API key authentication middleware
        #
        # @param app [#call] The next middleware in the Faraday stack
        # @param options [Hash] Configuration options
        # @option options [String] :api_key The API key for authentication
        # @raise [KeyError] If :api_key option is not provided
        def initialize(app, options = {})
          super(app)

          @api_key = options.fetch(:api_key)
        end

        # Process the HTTP request and add API key authentication
        #
        # Adds the API key as a Bearer token in the Authorization header if
        # no authorization header is already present, then passes the request
        # to the next middleware in the stack.
        #
        # @param env [Faraday::Env] The request environment
        # @return [Faraday::Response] The response from the next middleware
        def call(env)
          env.request_headers["Authorization"] ||= "Bearer #{@api_key}"

          @app.call(env)
        end
      end
    end
  end
end
