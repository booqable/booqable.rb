module BQBL
  # Authentication methods for {BQBL::Client}
  #
  # Provides authentication support for multiple methods including OAuth2,
  # API keys, and single-use tokens. The module automatically detects which
  # authentication method to use based on the configured credentials.
  #
  # @example OAuth authentication
  #   client = BQBL::Client.new(
  #     client_id: "your_client_id",
  #     client_secret: "your_client_secret"
  #   )
  #   client.authenticate_with_code("auth_code_from_callback")
  #
  # @example API key authentication
  #   client = BQBL::Client.new(api_key: "your_api_key")
  #   # Authentication is automatic with API requests
  #
  # @example Single-use token authentication
  #   client = BQBL::Client.new(
  #     single_use_token: "your_token",
  #     single_use_token_algorithm: "HS256",
  #     single_use_token_secret: "your_secret"
  #   )
  module Auth
    # Complete OAuth authentication flow with authorization code
    #
    # Exchanges an authorization code for an access token and stores it
    # using the configured write_token proc. This method should be called
    # after the user has been redirected back from the OAuth provider.
    #
    # @param code [String] Authorization code from OAuth callback
    # @return [void]
    # @raise [OAuth2::Error] If the authorization code is invalid or expired
    #
    # @example
    #   # In your OAuth callback handler
    #   client.authenticate_with_code(params[:code])
    def authenticate_with_code(code)
      token = oauth_client.get_token_from_code(code)
      @write_token.call(token.to_hash)
    end

    # Inject appropriate authentication middleware into the request stack
    #
    # Automatically detects which authentication method is configured and
    # injects the corresponding middleware. Multiple authentication methods
    # can be configured, with OAuth taking precedence over API keys.
    #
    # @param builder [Faraday::Builder] The middleware builder to configure
    # @return [void]
    # @api private
    def inject_auth_middleware(builder)
      builder.use BQBL::Middleware::Auth::OAuth, {
        client_id: client_id,
        client_secret: client_secret,
        api_endpoint: api_endpoint,
        redirect_uri: redirect_uri,
        read_token: read_token,
        write_token: write_token
      } if oauth_authenticated?

      builder.use BQBL::Middleware::Auth::ApiKey, {
        api_key: api_key
      } if api_key_authenticated?

      builder.use BQBL::Middleware::Auth::SingleUse, {
        single_use_token: single_use_token,
        single_use_token_algorithm: single_use_token_algorithm,
        single_use_token_private_key: single_use_token_private_key || single_use_token_secret,
        single_use_token_expiration_period: single_use_token_expiration_period,
        single_use_token_company_id: single_use_token_company_id,
        single_use_token_user_id: single_use_token_user_id,
        api_endpoint: api_endpoint
      } if single_use_token_authenticated?
    end

    # Get or create the OAuth client
    #
    # Returns a memoized OAuth client instance configured with the current
    # client credentials. Returns nil if OAuth is not configured.
    #
    # @return [OAuthClient, nil] OAuth client instance or nil if not configured
    def oauth_client
      @oauth_client ||= OAuthClient.new(
        api_endpoint: api_endpoint,
        client_id: @client_id,
        client_secret: @client_secret,
        redirect_uri: @redirect_uri
      ) if oauth_authenticated?
    end

    # Check if OAuth authentication is configured
    #
    # @return [Boolean] true if both client_id and client_secret are present
    def oauth_authenticated?
      !!@client_id && !!@client_secret
    end

    # Check if API key authentication is configured
    #
    # @return [Boolean] true if api_key is present
    def api_key_authenticated?
      !!@api_key
    end

    # Check if single-use token authentication is configured
    #
    # @return [Boolean] true if single_use_token is present
    def single_use_token_authenticated?
      !!@single_use_token
    end
  end
end
