# frozen_string_literal: true

describe BQBL::OAuthClient do
  describe "OAuth client functionality" do
    let(:test_redirect_uri) { "https://example.com/callback" }
    let(:test_code) { "test_authorization_code" }
    let(:test_base_url) { "https://demo.booqable.test" }

    describe "BQBL::OAuthClient" do
      it "can be instantiated with required parameters" do
        oauth_client = BQBL::OAuthClient.new(
          base_url: test_base_url,
          client_id: test_client_id,
          client_secret: test_client_secret,
          redirect_uri: test_redirect_uri
        )

        expect(oauth_client).to be_a(BQBL::OAuthClient)
      end

      it "has the correct token endpoint" do
        expect(BQBL::OAuthClient::TOKEN_ENDPOINT).to eq("/oauth/token")
      end

      it "constructs token_url with base_url prepended" do
        oauth_client = BQBL::OAuthClient.new(
          base_url: test_base_url,
          client_id: test_client_id,
          client_secret: test_client_secret,
          redirect_uri: test_redirect_uri
        )

        # Access the underlying OAuth2::Client instance
        oauth2_client = oauth_client.instance_variable_get(:@client)
        expect(oauth2_client.options[:token_url]).to eq("#{test_base_url}/oauth/token")
      end

      describe "#get_token_from_code", :vcr do
        it "exchanges authorization code for access token" do
          # Mock the OAuth2 client response
          mock_client = double("OAuth2::Client")
          mock_auth_code = double("OAuth2::Strategy::AuthCode")
          mock_token = double("OAuth2::AccessToken",
            token: "access_token_123",
            refresh_token: "refresh_token_456",
            expires_at: Time.now + 3600,
            to_hash: {
              "access_token" => "access_token_123",
              "refresh_token" => "refresh_token_456",
              "expires_at" => Time.now + 3600
            }
          )

          allow(OAuth2::Client).to receive(:new).and_return(mock_client)
          allow(mock_client).to receive(:auth_code).and_return(mock_auth_code)
          allow(mock_auth_code).to receive(:get_token).and_return(mock_token)

          oauth_client = BQBL::OAuthClient.new(
            base_url: test_base_url,
            client_id: test_client_id,
            client_secret: test_client_secret,
            redirect_uri: test_redirect_uri
          )

          token = oauth_client.get_token_from_code(test_code)

          expect(token).to respond_to(:token)
          expect(token).to respond_to(:refresh_token)
          expect(token).to respond_to(:expires_at)
          expect(token).to respond_to(:to_hash)
        end

        it "includes correct parameters in token request" do
          mock_client = double("OAuth2::Client")
          mock_auth_code = double("OAuth2::Strategy::AuthCode")

          allow(OAuth2::Client).to receive(:new).and_return(mock_client)
          allow(mock_client).to receive(:auth_code).and_return(mock_auth_code)

          expect(mock_auth_code).to receive(:get_token).with(
            test_code,
            redirect_uri: test_redirect_uri,
            scope: "full_access",
            grant_type: "authorization_code"
          )

          oauth_client = BQBL::OAuthClient.new(
            base_url: test_base_url,
            client_id: test_client_id,
            client_secret: test_client_secret,
            redirect_uri: test_redirect_uri
          )

          oauth_client.get_token_from_code(test_code)
        end

        it "accepts custom scope parameter" do
          mock_client = double("OAuth2::Client")
          mock_auth_code = double("OAuth2::Strategy::AuthCode")

          allow(OAuth2::Client).to receive(:new).and_return(mock_client)
          allow(mock_client).to receive(:auth_code).and_return(mock_auth_code)

          expect(mock_auth_code).to receive(:get_token).with(
            test_code,
            redirect_uri: test_redirect_uri,
            scope: "read_only",
            grant_type: "authorization_code"
          )

          oauth_client = BQBL::OAuthClient.new(
            base_url: test_base_url,
            client_id: test_client_id,
            client_secret: test_client_secret,
            redirect_uri: test_redirect_uri
          )

          oauth_client.get_token_from_code(test_code, scope: "read_only")
        end
      end
    end

    describe "oauth_client method" do
      it "creates OAuthClient instance when oauth authenticated" do
        client = BQBL::Client.new(
          client_id: test_client_id,
          client_secret: test_client_secret,
          redirect_uri: test_redirect_uri,
          api_domain: "booqable.test",
          company: "demo"
        )

        oauth_client = client.oauth_client
        expect(oauth_client).to be_a(BQBL::OAuthClient)
      end

      it "returns nil when not oauth authenticated" do
        client = BQBL::Client.new(
          api_domain: "booqable.test",
          company: "demo"
        )

        expect(client.oauth_client).to be_nil
      end

      it "memoizes the oauth client instance" do
        client = BQBL::Client.new(
          client_id: test_client_id,
          client_secret: test_client_secret,
          redirect_uri: test_redirect_uri,
          api_domain: "booqable.test",
          company: "demo"
        )

        oauth_client1 = client.oauth_client
        oauth_client2 = client.oauth_client
        expect(oauth_client1.object_id).to eq(oauth_client2.object_id)
      end
    end

    describe "authenticate_with_code method" do
      it "exchanges code for token and stores it" do
        stored_token = nil

        client = BQBL::Client.new(
          client_id: test_client_id,
          client_secret: test_client_secret,
          redirect_uri: test_redirect_uri,
          api_domain: "booqable.test",
          company: "demo",
          write_token: ->(token) { stored_token = token }
        )

        # Mock the OAuth client to return a token
        mock_token = double("AccessToken",
          token: "access_token_123",
          refresh_token: "refresh_token_456",
          expires_at: Time.now + 3600,
          to_hash: {
            "access_token" => "access_token_123",
            "refresh_token" => "refresh_token_456",
            "expires_at" => Time.now + 3600
          }
        )

        allow(client.oauth_client).to receive(:get_token_from_code).and_return(mock_token)

        client.authenticate_with_code(test_code)

        expect(stored_token).to eq(mock_token.to_hash)
      end

      it "raises error when oauth client is not available" do
        client = BQBL::Client.new(
          api_domain: "booqable.test",
          company: "demo"
        )

        expect { client.authenticate_with_code(test_code) }.to raise_error(NoMethodError)
      end
    end

    describe "token management" do
      it "supports read_token lambda for retrieving stored tokens" do
        stored_token = {
          "access_token" => "stored_access_token",
          "refresh_token" => "stored_refresh_token",
          "expires_at" => Time.now + 3600
        }

        client = BQBL::Client.new(
          client_id: test_client_id,
          client_secret: test_client_secret,
          redirect_uri: test_redirect_uri,
          api_domain: "booqable.test",
          company: "demo",
          read_token: -> { stored_token }
        )

        expect(client.instance_variable_get(:@read_token).call).to eq(stored_token)
      end

      it "supports write_token lambda for storing tokens" do
        stored_token = nil

        client = BQBL::Client.new(
          client_id: test_client_id,
          client_secret: test_client_secret,
          redirect_uri: test_redirect_uri,
          api_domain: "booqable.test",
          company: "demo",
          write_token: ->(token) { stored_token = token }
        )

        test_token = { "access_token" => "test_token" }
        client.instance_variable_get(:@write_token).call(test_token)

        expect(stored_token).to eq(test_token)
      end
    end

    describe "OAuth configuration" do
      it "requires client_id for OAuth authentication" do
        client = BQBL::Client.new(
          client_secret: test_client_secret,
          redirect_uri: test_redirect_uri,
          api_domain: "booqable.test",
          company: "demo"
        )

        expect(client.oauth_authenticated?).to be false
      end

      it "requires client_secret for OAuth authentication" do
        client = BQBL::Client.new(
          client_id: test_client_id,
          redirect_uri: test_redirect_uri,
          api_domain: "booqable.test",
          company: "demo"
        )

        expect(client.oauth_authenticated?).to be false
      end

      it "supports redirect_uri configuration" do
        client = BQBL::Client.new(
          client_id: test_client_id,
          client_secret: test_client_secret,
          redirect_uri: test_redirect_uri,
          api_domain: "booqable.test",
          company: "demo"
        )

        expect(client.instance_variable_get(:@redirect_uri)).to eq(test_redirect_uri)
      end
    end

    describe "OAuth middleware integration" do
      it "handles token refresh through middleware" do
        stored_token = {
          "access_token" => "old_token",
          "refresh_token" => "refresh_token_123",
          "expires_at" => Time.now - 3600
        }

        new_token = {
          "access_token" => "new_token",
          "refresh_token" => "new_refresh_token",
          "expires_at" => Time.now + 3600
        }

        client = BQBL::Client.new(
          client_id: test_client_id,
          client_secret: test_client_secret,
          redirect_uri: test_redirect_uri,
          api_domain: "booqable.test",
          company: "demo",
          read_token: -> { stored_token },
          write_token: ->(token) { stored_token = token }
        )

        # Mock the OAuth2 token refresh process
        new_oauth_token = double("NewAccessToken",
          to_hash: new_token,
          token: new_token["access_token"]
        )

        old_oauth_token = double("OldAccessToken",
          expired?: true,
          refresh!: new_oauth_token
        )

        allow(OAuth2::AccessToken).to receive(:from_hash).and_return(old_oauth_token)

        middleware = BQBL::Middleware::Auth::OAuth.new(
          ->(env) { env },
          client_id: test_client_id,
          client_secret: test_client_secret,
          base_url: "http://demo.booqable.test",
          redirect_uri: test_redirect_uri,
          read_token: client.instance_variable_get(:@read_token),
          write_token: client.instance_variable_get(:@write_token)
        )

        env = double("Environment")
        allow(env).to receive(:request_headers).and_return({})
        allow(env).to receive(:[]=)

        middleware.call(env)

        expect(stored_token).to eq(new_token)
      end

      it "handles OAuth errors during token refresh" do
        stored_token = {
          "access_token" => "old_token",
          "refresh_token" => "invalid_refresh_token",
          "expires_at" => Time.now - 3600
        }

        client = BQBL::Client.new(
          client_id: test_client_id,
          client_secret: test_client_secret,
          redirect_uri: test_redirect_uri,
          api_domain: "booqable.test",
          company: "demo",
          read_token: -> { stored_token },
          write_token: ->(token) { stored_token = token }
        )

        # Mock OAuth2 error during refresh
        old_oauth_token = double("OldAccessToken",
          expired?: true,
          token: stored_token["access_token"]
        )
        oauth_error = OAuth2::Error.new(double("Response",
          response: double("HttpResponse",
            env: double("Env",
              to_h: {
                status: 401,
                body: '{"error": "invalid_grant"}'
              }
            )
          )
        ))

        allow(OAuth2::AccessToken).to receive(:from_hash).and_return(old_oauth_token)
        allow(old_oauth_token).to receive(:refresh!).and_raise(oauth_error)

        middleware = BQBL::Middleware::Auth::OAuth.new(
          ->(env) { env },
          client_id: test_client_id,
          client_secret: test_client_secret,
          base_url: "http://demo.booqable.test",
          redirect_uri: test_redirect_uri,
          read_token: client.instance_variable_get(:@read_token),
          write_token: client.instance_variable_get(:@write_token)
        )

        env = double("Environment")
        allow(env).to receive(:request_headers).and_return({})
        allow(env).to receive(:[]=)

        expect(BQBL::Error).to receive(:from_response).with({
          status: 401,
          body: '{"error": "invalid_grant"}'
        }).and_raise(BQBL::Unauthorized)

        expect { middleware.call(env) }.to raise_error(BQBL::Unauthorized)
      end
    end
  end
end
