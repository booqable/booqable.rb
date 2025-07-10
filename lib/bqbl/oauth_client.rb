# frozen_string_literal: true

require "oauth2"

module BQBL
  # OAuth2 client for Booqable API authentication
  #
  # Provides OAuth2 authentication flow support for the Booqable API.
  # Handles authorization code exchange for access tokens using the
  # standard OAuth2 authorization code flow.
  #
  # @example Basic OAuth flow
  #   oauth_client = BQBL::OAuthClient.new(
  #     base_url: "https://demo.booqable.com",
  #     client_id: "your_client_id",
  #     client_secret: "your_client_secret",
  #     redirect_uri: "https://yourapp.com/callback"
  #   )
  #
  #   # After user authorizes and returns with code
  #   token = oauth_client.get_token_from_code(params[:code])
  #   access_token = token.token
  class OAuthClient
    # OAuth2 token endpoint path
    TOKEN_ENDPOINT = "/oauth/token"

    # Initialize a new OAuth client
    #
    # @param base_url [String] Base URL of the Booqable instance (e.g., "https://demo.booqable.com")
    # @param client_id [String] OAuth2 client identifier
    # @param client_secret [String] OAuth2 client secret
    # @param redirect_uri [String] OAuth2 redirect URI for authorization callback
    def initialize(base_url:, client_id:, client_secret:, redirect_uri:)
      @client = OAuth2::Client.new(
        client_id,
        client_secret,
        site: base_url,
        token_url: TOKEN_ENDPOINT
      )
      @redirect_uri = redirect_uri
    end

    # Exchange an authorization code for an access token
    #
    # Exchanges the authorization code received from the OAuth callback
    # for an access token that can be used to make API requests.
    #
    # @param code [String] Authorization code from OAuth callback
    # @param scope [String] OAuth scope to request (default: "full_access")
    # @return [OAuth2::AccessToken] Access token object with token and refresh token
    # @raise [OAuth2::Error] If the authorization code is invalid or expired
    #
    # @example
    #   token = oauth_client.get_token_from_code("auth_code_123")
    #   access_token = token.token
    #   refresh_token = token.refresh_token
    def get_token_from_code(code, scope: "full_access")
      @client.auth_code.get_token(code,
                                  redirect_uri: @redirect_uri,
                                  scope: scope,
                                  grant_type: "authorization_code")
    end
  end
end
