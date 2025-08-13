# frozen_string_literal: true

describe Booqable::Client do
  describe "configuration validation" do
    it "raises CompanyRequired when company is not set" do
      client = Booqable::Client.new(
        api_domain: "booqable.test",
        api_key: test_api_key,
        company: nil
      )

      expect { client.send(:api_endpoint) }.to raise_error(Booqable::CompanyRequired)
    end

    it "raises CompanyRequired when company is empty string" do
      client = Booqable::Client.new(
        api_domain: "booqable.test",
        api_key: test_api_key,
        company: ""
      )

      expect { client.send(:api_endpoint) }.to raise_error(Booqable::CompanyRequired)
    end
  end

  describe "module configuration" do
    before do
      Booqable.configure do |config|
        # rubocop:disable Style/HashEachMethods
        #
        # This may look like a `.keys.each` which should be replaced with `#each_key`, but
        # this doesn't actually work, since `#keys` is just a method we've defined ourselves.
        # The class doesn't fulfill the whole `Enumerable` contract.
        Booqable::Configurable.keys.each do |key|
          # rubocop:enable Style/HashEachMethods
          config.send("#{key}=", "#{booqable_defaults.fetch(key, "Some #{key}")}")
        end
      end
    end

    after do
      Booqable.reset!
    end

    it "inherits the module configuration" do
      client = Booqable::Client.new

      # rubocop:disable Style/HashEachMethods
      #
      # This may look like a `.keys.each` which should be replaced with `#each_key`, but
      # this doesn't actually work, since
      # `#keys` is just a method we've defined ourselves.
      # The class doesn't fulfill the whole `Enumerable` contract.
      Booqable::Configurable.keys.each do |key|
        # rubocop:enable Style/HashEachMethods
        expect(client.instance_variable_get(:"@#{key}")).to eq(booqable_defaults.fetch(key, "Some #{key}"))
      end
    end

    describe "with class level configuration" do
      before do
        @opts = {
          connection_options: { ssl: { verify: false } },
          per_page: 40
        }
      end

      it "uses defaults when parameters are nil" do
        new_opts = @opts.merge(api_endpoint: nil)
        client = Booqable::Client.new(new_opts)
        expect(client.api_endpoint).to eq(Booqable.api_endpoint)
      end

      it "overrides module configuration" do
        client = Booqable::Client.new(@opts)
        expect(client.per_page).to eq(40)
        expect(client.auto_paginate).to eq(Booqable.auto_paginate)
        expect(client.client_id).to eq(Booqable.client_id)
      end

      it "can set configuration after initialization" do
        client = Booqable::Client.new
        client.configure do |config|
          @opts.each do |key, value|
            config.send("#{key}=", value)
          end
        end
        expect(client.per_page).to eq(40)
        expect(client.auto_paginate).to eq(Booqable.auto_paginate)
        expect(client.client_id).to eq(Booqable.client_id)
      end

      it "masks api token on inspect" do
        client = Booqable::Client.new(api_token: "87614b09dd141c22800f96f11737ade5226d7ba8")
        inspected = client.inspect
        expect(inspected).not_to include("87614b09dd141c22800f96f11737ade5226d7ba8")
      end

      it "masks single use token on inspect" do
        client = Booqable::Client.new(single_use_token: "secret JWT")
        inspected = client.inspect
        expect(inspected).not_to include("secret JWT")
      end

      it "masks client secret on inspect" do
        client = Booqable::Client.new(client_secret: "87614b09dd141c22800f96f11737ade5226d7ba8")
        inspected = client.inspect
        expect(inspected).not_to include("87614b09dd141c22800f96f11737ade5226d7ba8")
      end

      it "masks client id on inspect" do
        client = Booqable::Client.new(client_id: "87614b09dd141c22800f96f11737ade5226d7ba8")
        inspected = client.inspect
        expect(inspected).not_to include("87614b09dd141c22800f96f11737ade5226d7ba8")
      end

      it "masks single use token private key on inspect" do
        client = Booqable::Client.new(single_use_token_private_key: "87614b09dd141c22800f96f11737ade5226d7ba8")
        inspected = client.inspect
        expect(inspected).not_to include("87614b09dd141c22800f96f11737ade5226d7ba8")
      end

      it "masks single use token secret on inspect" do
        client = Booqable::Client.new(single_use_token_secret: "87614b09dd141c22800f96f11737ade5226d7ba8")
        inspected = client.inspect
        expect(inspected).not_to include("87614b09dd141c22800f96f11737ade5226d7ba8")
      end
    end
  end

  describe "content type" do
    before do
      Booqable.reset!
      Booqable.configure do |config|
        config.api_domain = "booqable.test"
        config.company = "demo"
        config.api_version = "4"
      end
    end

    it "sets a default Content-Type header" do
      orders_request = stub_post("/orders")
                     .with({
                             headers: { "Content-Type" => "application/vnd.api+json" }
                           })

      Booqable.client.post "/orders", {}
      assert_requested orders_request
    end
  end

  describe "authentication" do
    before do
      Booqable.reset!
      @client = Booqable.client
    end

    describe "with module level config" do
      before do
        Booqable.reset!
      end

      it "sets api key with .configure" do
        Booqable.configure do |config|
          config.api_key = test_api_key
        end
        expect(Booqable.client).to be_api_key_authenticated
        expect(Booqable.client).not_to be_oauth_authenticated
        expect(Booqable.client).not_to be_single_use_token_authenticated
      end

      it "sets api key with module methods" do
        Booqable.api_key = test_api_key
        expect(Booqable.client).to be_api_key_authenticated
        expect(Booqable.client).not_to be_oauth_authenticated
        expect(Booqable.client).not_to be_single_use_token_authenticated
      end

      it "sets oauth token with .configure" do
        Booqable.configure do |config|
          config.client_id = test_client_id
          config.client_secret = test_client_secret
        end
        expect(Booqable.client).to be_oauth_authenticated
        expect(Booqable.client).not_to be_api_key_authenticated
        expect(Booqable.client).not_to be_single_use_token_authenticated
      end

      it "sets oauth token with module methods" do
        Booqable.client_id = test_client_id
        Booqable.client_secret = test_client_secret
        expect(Booqable.client).to be_oauth_authenticated
        expect(Booqable.client).not_to be_api_key_authenticated
        expect(Booqable.client).not_to be_single_use_token_authenticated
      end

      it "sets single use token with .configure" do
        Booqable.configure do |config|
          config.single_use_token_company_id = test_single_use_token_company_id
          config.single_use_token_user_id = test_single_use_token_user_id
          config.single_use_token_algorithm = test_single_use_token_algorithm
          config.single_use_token = test_single_use_token
          config.single_use_token_secret = test_single_use_token_private_key
        end
        expect(Booqable.client).to be_single_use_token_authenticated
        expect(Booqable.client).not_to be_api_key_authenticated
        expect(Booqable.client).not_to be_oauth_authenticated
      end

      it "sets single use token with module methods" do
        Booqable.single_use_token_company_id = test_single_use_token_company_id
        Booqable.single_use_token_user_id = test_single_use_token_user_id
        Booqable.single_use_token_algorithm = test_single_use_token_algorithm
        Booqable.single_use_token = test_single_use_token
        Booqable.single_use_token_secret = test_single_use_token_private_key

        expect(Booqable.client).to be_single_use_token_authenticated
        expect(Booqable.client).not_to be_api_key_authenticated
        expect(Booqable.client).not_to be_oauth_authenticated
      end
    end

    describe "with class level config" do
      it "sets api key with .configure" do
        @client.configure do |config|
          config.api_key = test_api_key
        end
        expect(@client).to be_api_key_authenticated
        expect(@client).not_to be_oauth_authenticated
        expect(@client).not_to be_single_use_token_authenticated
      end

      it "sets api key with module methods" do
        @client.api_key = test_api_key
        expect(@client).to be_api_key_authenticated
        expect(@client).not_to be_oauth_authenticated
        expect(@client).not_to be_single_use_token_authenticated
      end

      it "sets oauth token with .configure" do
        @client.configure do |config|
          config.client_id = test_client_id
          config.client_secret = test_client_secret
        end
        expect(@client).to be_oauth_authenticated
        expect(@client).not_to be_api_key_authenticated
        expect(@client).not_to be_single_use_token_authenticated
      end

      it "sets oauth token with module methods" do
        @client.client_id = test_client_id
        @client.client_secret = test_client_secret
        expect(@client).to be_oauth_authenticated
        expect(@client).not_to be_api_key_authenticated
        expect(@client).not_to be_single_use_token_authenticated
      end

      it "sets single use token with .configure" do
        @client.configure do |config|
          config.single_use_token_company_id = test_single_use_token_company_id
          config.single_use_token_user_id = test_single_use_token_user_id
          config.single_use_token_algorithm = test_single_use_token_algorithm
          config.single_use_token = test_single_use_token
          config.single_use_token_secret = test_single_use_token_private_key
        end
        expect(@client).to be_single_use_token_authenticated
        expect(@client).not_to be_api_key_authenticated
        expect(@client).not_to be_oauth_authenticated
      end

      it "sets single use token with module methods" do
        @client.single_use_token_company_id = test_single_use_token_company_id
        @client.single_use_token_user_id = test_single_use_token_user_id
        @client.single_use_token_algorithm = test_single_use_token_algorithm
        @client.single_use_token = test_single_use_token
        @client.single_use_token_secret = test_single_use_token_private_key

        expect(@client).to be_single_use_token_authenticated
        expect(@client).not_to be_api_key_authenticated
        expect(@client).not_to be_oauth_authenticated
      end
    end

    describe "when api token authenticated", :vcr do
      it "makes authenticated calls" do
        client = api_key_client

        orders_request = stub_get("/orders")
                       .with(headers: { authorization: "Bearer #{test_api_key}" })
        client.get("/orders")
        assert_requested orders_request
      end

      it "memoizes api key" do
        client = api_key_client

        expect(client.api_key).to eq(test_api_key)
      end
    end

    describe "when oauth authenticated" do
      it "makes authenticated calls" do
        client = Booqable::Client.new(
          company: "demo",
          api_domain: "booqable.test",
          client_id: test_client_id,
          client_secret: test_client_secret,
          write_token: ->(token) {
          },
          read_token: -> {
            {
              access_token: test_access_token,
              refresh_token: test_refresh_token,
              expires_at: Time.now + 3600
            }
          }
        )

        orders_request = stub_request(:get, booqable_url("/orders")).with(headers: { authorization: "Bearer #{test_access_token}" })

        client.get("/orders")

        assert_requested orders_request
      end

      it "refreshes expired tokens automatically" do
        refreshed_token = "new_access_token_456"
        stored_token = nil

        client = Booqable::Client.new(
          company: "demo",
          api_domain: "booqable.test",
          client_id: test_client_id,
          client_secret: test_client_secret,
          write_token: ->(token) { stored_token = token },
          read_token: -> {
            {
              access_token: test_access_token,
              refresh_token: test_refresh_token,
              expires_at: Time.now - 3600  # Expired token
            }
          }
        )

        # Mock the OAuth2 token refresh
        mock_token = double("AccessToken",
          token: refreshed_token,
          refresh_token: "new_refresh_token",
          expires_at: Time.now + 3600,
          expired?: true,
          to_hash: {
            "access_token" => refreshed_token,
            "refresh_token" => "new_refresh_token",
            "expires_at" => Time.now + 3600
          }
        )

        refreshed_mock_token = double("AccessToken",
          token: refreshed_token,
          refresh_token: "new_refresh_token",
          expires_at: Time.now + 3600,
          to_hash: {
            "access_token" => refreshed_token,
            "refresh_token" => "new_refresh_token",
            "expires_at" => Time.now + 3600
          }
        )

        allow(OAuth2::AccessToken).to receive(:from_hash).and_return(mock_token)
        allow(mock_token).to receive(:refresh!).and_return(refreshed_mock_token)

        orders_request = stub_request(:get, booqable_url("/orders")).with(headers: { authorization: "Bearer #{refreshed_token}" })

        client.get("/orders")

        assert_requested orders_request
        expect(stored_token).to eq(refreshed_mock_token.to_hash)
      end

      it "handles OAuth2 errors during token refresh" do
        client = Booqable::Client.new(
          company: "demo",
          api_domain: "booqable.test",
          client_id: test_client_id,
          client_secret: test_client_secret,
          write_token: ->(token) { },
          read_token: -> {
            {
              access_token: test_access_token,
              refresh_token: test_refresh_token,
              expires_at: Time.now - 3600  # Expired token
            }
          }
        )

        # Mock the OAuth2 token refresh to fail
        mock_token = double("AccessToken", expired?: true)
        oauth_error = OAuth2::Error.new("invalid_grant")

        # Mock the error response
        mock_response = double("Response",
          response: double("HTTPResponse",
            env: double("Env",
              to_h: {
                status: 401,
                body: '{"error": "invalid_grant"}',
                response_headers: { "Content-Type" => "application/json" },
                method: :post,
                url: "https://demo.booqable.test/oauth/token"
              }
            )
          )
        )

        allow(oauth_error).to receive(:response).and_return(mock_response)
        allow(OAuth2::AccessToken).to receive(:from_hash).and_return(mock_token)
        allow(mock_token).to receive(:refresh!).and_raise(oauth_error)

        # Mock Booqable::Error.from_response to raise an appropriate error
        allow(Booqable::Error).to receive(:from_response).and_raise(Booqable::Unauthorized)

        expect { client.get("/orders") }.to raise_error(Booqable::Unauthorized)
      end

      it "injects oauth middleware when oauth authenticated" do
        client = Booqable::Client.new(
          company: "demo",
          api_domain: "booqable.test",
          client_id: test_client_id,
          client_secret: test_client_secret,
          write_token: ->(token) { },
          read_token: -> { { access_token: test_access_token } }
        )

        builder = double("Builder")
        expect(builder).to receive(:use).with(Booqable::Middleware::Auth::OAuth, hash_including(
          client_id: test_client_id,
          client_secret: test_client_secret
        ))
        expect(builder).not_to receive(:use).with(Booqable::Middleware::Auth::ApiKey, anything)
        expect(builder).not_to receive(:use).with(Booqable::Middleware::Auth::SingleUse, anything)

        client.send(:inject_auth_middleware, builder)
      end

      it "does not inject oauth middleware when not oauth authenticated" do
        client = Booqable::Client.new(
          company: "demo",
          api_domain: "booqable.test",
          api_key: test_api_key
        )

        builder = double("Builder")
        expect(builder).not_to receive(:use).with(Booqable::Middleware::Auth::OAuth, anything)
        expect(builder).to receive(:use).with(Booqable::Middleware::Auth::ApiKey, hash_including(
          api_key: test_api_key
        ))
        expect(builder).not_to receive(:use).with(Booqable::Middleware::Auth::SingleUse, anything)

        client.send(:inject_auth_middleware, builder)
      end
    end

    describe "when single use token authenticated" do
      let(:es256_private_key) do
        OpenSSL::PKey::EC.generate("prime256v1").to_pem
      end

      let(:rs256_private_key) do
        OpenSSL::PKey::RSA.generate(2048).to_pem
      end

      let(:hs256_secret) do
        "super_secret_key_for_hmac_256"
      end

      describe "with ES256 algorithm" do
        it "makes authenticated calls with ES256" do
          client = Booqable::Client.new(
            company: "demo",
            api_domain: "booqable.test",
            single_use_token_company_id: test_single_use_token_company_id,
            single_use_token_user_id: test_single_use_token_user_id,
            single_use_token_algorithm: "ES256",
            single_use_token: test_single_use_token,
            single_use_token_private_key: es256_private_key
          )

          orders_request = stub_request(:get, booqable_url("/orders"))
            .with do |req|
              req.headers["Authorization"] =~ /^Bearer .+/
            end

          client.get("/orders")

          assert_requested orders_request
        end

        it "generates valid JWT tokens with ES256" do
          client = Booqable::Client.new(
            company: "demo",
            api_domain: "booqable.test",
            single_use_token_company_id: test_single_use_token_company_id,
            single_use_token_user_id: test_single_use_token_user_id,
            single_use_token_algorithm: "ES256",
            single_use_token: test_single_use_token,
            single_use_token_private_key: es256_private_key
          )

          stub_request(:get, booqable_url("/orders"))

          client.get("/orders")

          expect(client).to be_single_use_token_authenticated
        end
      end

      describe "with RS256 algorithm" do
        it "makes authenticated calls with RS256" do
          client = Booqable::Client.new(
            company: "demo",
            api_domain: "booqable.test",
            single_use_token_company_id: test_single_use_token_company_id,
            single_use_token_user_id: test_single_use_token_user_id,
            single_use_token_algorithm: "RS256",
            single_use_token: test_single_use_token,
            single_use_token_private_key: rs256_private_key
          )

          orders_request = stub_request(:get, booqable_url("/orders"))
            .with do |req|
              req.headers["Authorization"] =~ /^Bearer .+/
            end

          client.get("/orders")

          assert_requested orders_request
        end

        it "generates valid JWT tokens with RS256" do
          client = Booqable::Client.new(
            company: "demo",
            api_domain: "booqable.test",
            single_use_token_company_id: test_single_use_token_company_id,
            single_use_token_user_id: test_single_use_token_user_id,
            single_use_token_algorithm: "RS256",
            single_use_token: test_single_use_token,
            single_use_token_private_key: rs256_private_key
          )

          stub_request(:get, booqable_url("/orders"))

          client.get("/orders")

          expect(client).to be_single_use_token_authenticated
        end
      end

      describe "with HS256 algorithm" do
        it "makes authenticated calls with HS256" do
          client = Booqable::Client.new(
            company: "demo",
            api_domain: "booqable.test",
            single_use_token_company_id: test_single_use_token_company_id,
            single_use_token_user_id: test_single_use_token_user_id,
            single_use_token_algorithm: "HS256",
            single_use_token: test_single_use_token,
            single_use_token_private_key: hs256_secret
          )

          orders_request = stub_request(:get, booqable_url("/orders"))
            .with do |req|
              req.headers["Authorization"] =~ /^Bearer .+/
            end

          client.get("/orders")

          assert_requested orders_request
        end

        it "generates valid JWT tokens with HS256" do
          client = Booqable::Client.new(
            company: "demo",
            api_domain: "booqable.test",
            single_use_token_company_id: test_single_use_token_company_id,
            single_use_token_user_id: test_single_use_token_user_id,
            single_use_token_algorithm: "HS256",
            single_use_token: test_single_use_token,
            single_use_token_private_key: hs256_secret
          )

          stub_request(:get, booqable_url("/orders"))

          client.get("/orders")

          expect(client).to be_single_use_token_authenticated
        end
      end

      describe "JWT payload validation" do
        it "includes required claims in JWT payload" do
          client = Booqable::Client.new(
            company: "demo",
            api_domain: "booqable.test",
            single_use_token_company_id: test_single_use_token_company_id,
            single_use_token_user_id: test_single_use_token_user_id,
            single_use_token_algorithm: "ES256",
            single_use_token: test_single_use_token,
            single_use_token_private_key: es256_private_key
          )

          stub_request(:get, booqable_url("/orders"))

          # Mock the Faraday env to capture the generated token
          captured_token = nil

          allow_any_instance_of(Booqable::Middleware::Auth::SingleUse).to(
            receive(:generate_token).and_wrap_original do |original_method, *args|
              captured_token = original_method.call(*args)
            end
          )

          client.get("/orders")

          # Decode the JWT to verify payload structure
          decoded_payload = JWT.decode(captured_token, nil, false).first

          expect(decoded_payload["alg"]).to eq("ES256")
          expect(decoded_payload["iat"]).to be_a(Integer)
          expect(decoded_payload["exp"]).to be_a(Integer)
          expect(decoded_payload["aud"]).to eq(test_single_use_token_company_id)
          expect(decoded_payload["sub"]).to eq(test_single_use_token_user_id)
          expect(decoded_payload["iss"]).to eq("https://demo.booqable.com")
          expect(decoded_payload["jti"]).to be_a(String)
        end
      end

      describe "error handling" do
        it "raises error when algorithm is missing" do
          expect do
            client = Booqable::Client.new(
              company: "demo",
              api_domain: "booqable.test",
              single_use_token_company_id: test_single_use_token_company_id,
              single_use_token_user_id: test_single_use_token_user_id,
              single_use_token: test_single_use_token,
              single_use_token_private_key: es256_private_key
            )
            client.get("/orders")
          end.to raise_error(Booqable::SingleUseTokenAlgorithmRequired)
        end

        it "raises error when company_id is missing" do
          expect do
            client = Booqable::Client.new(
              company: "demo",
              api_domain: "booqable.test",
              single_use_token_user_id: test_single_use_token_user_id,
              single_use_token_algorithm: "ES256",
              single_use_token: test_single_use_token,
              single_use_token_private_key: es256_private_key
            )
            client.get("/orders")
          end.to raise_error(Booqable::SingleUseTokenCompanyIdRequired)
        end

        it "raises error when user_id is missing" do
          expect do
            client = Booqable::Client.new(
              company: "demo",
              api_domain: "booqable.test",
              single_use_token_company_id: test_single_use_token_company_id,
              single_use_token_algorithm: "ES256",
              single_use_token: test_single_use_token,
              single_use_token_private_key: es256_private_key
            )
            client.get("/orders")
          end.to raise_error(Booqable::SingleUseTokenUserIdRequired)
        end

        it "raises error when private_key is missing" do
          expect do
            client = Booqable::Client.new(
              company: "demo",
              api_domain: "booqable.test",
              single_use_token_company_id: test_single_use_token_company_id,
              single_use_token_user_id: test_single_use_token_user_id,
              single_use_token_algorithm: "ES256",
              single_use_token: test_single_use_token
            )
            client.get("/orders")
          end.to raise_error(Booqable::PrivateKeyOrSecretRequired)
        end
      end
    end
  end

  describe ".agent" do
    before do
      Booqable.reset!
      Booqable.company = "demo"
    end

    it "acts like a Sawyer agent" do
      expect(Booqable.client.agent).to respond_to :start
    end

    it "caches the agent" do
      client = Booqable::Client.new
      agent = client.agent
      expect(agent.object_id).to eq(client.agent.object_id)
    end
  end # .agent

  describe ".last_response", :vcr do
    it "caches the last agent response" do
      Booqable.reset!

      client = Booqable.client
      client.api_key = test_api_key
      client.company = "demo"
      client.api_domain = "booqable.test"

      expect(client.last_response).to be_nil
      client.get "/orders"
      expect(client.last_response.status).to eq(200)
    end
  end # .last_response

  describe ".get", :vcr do
    before(:each) do
      Booqable.reset!
      Booqable.company = "demo"
      Booqable.api_domain = "booqable.test"
    end

    it "handles query params" do
      request = stub_get("/orders")
        .with(query: { foo: "bar" })
      Booqable.get "/orders", foo: "bar"
      assert_requested request
    end

    it "handles headers" do
      request = stub_get("/zen")
                .with(query: { foo: "bar" }, headers: { accept: "text/plain" })
      Booqable.get "/zen", foo: "bar", accept: "text/plain"
      assert_requested request
    end
  end # .get

  describe ".head", :vcr do
    before(:each) do
      Booqable.reset!
      Booqable.company = "demo"
      Booqable.api_domain = "booqable.test"
    end

    it "handles query params" do
      request = stub_head("/orders")
                .with(query: { foo: "bar" })
      Booqable.head "/orders", foo: "bar"
      assert_requested request
    end

    it "handles headers" do
      request = stub_head("/zen")
                .with(query: { foo: "bar" }, headers: { accept: "text/plain" })
      Booqable.head "/zen", foo: "bar", accept: "text/plain"
      assert_requested request
    end
  end # .head

  describe "when making requests" do
    before do
      Booqable.reset!
      Booqable.company = "demo"
      Booqable.api_domain = "booqable.test"
      @client = Booqable.client
    end

    it "Accepts application/vnd.api+json by default" do
      orders_request = stub_get("/orders")
                     .with(headers: { accept: "application/vnd.api+json" })
      @client.get "/orders"
      assert_requested orders_request
      expect(@client.last_response.status).to eq(200)
    end

    it "allows Accept'ing another media type" do
      orders_request = stub_get("/orders")
                     .with(headers: { accept: "application/json" })
      @client.get "/orders", accept: "application/json"
      assert_requested orders_request
      expect(@client.last_response.status).to eq(200)
    end

    it "sets a default user agent" do
      orders_request = stub_get("/orders")
                     .with(headers: { user_agent: Booqable::Default.user_agent })
      @client.get "/orders"
      assert_requested orders_request
      expect(@client.last_response.status).to eq(200)
    end

    it "sets a custom user agent" do
      user_agent = "Mozilla/5.0 I am Spartacus!"
      orders_request = stub_get("/orders")
                     .with(headers: { user_agent: user_agent })
      client = Booqable::Client.new(user_agent: user_agent)
      client.get "/orders"
      assert_requested orders_request
      expect(client.last_response.status).to eq(200)
    end

    it "sets a proxy server" do
      Booqable.configure do |config|
        config.proxy = "http://proxy.example.com:80"
      end
      conn = Booqable.client.send(:agent).instance_variable_get(:@conn)
      expect(conn.proxy[:uri].to_s).to eq("http://proxy.example.com")
    end

    it "sets ssl verify to SSL::VERIFY_PEER" do
      client = Booqable::Client.new
      expect(client.faraday_options[:ssl]).to eq({ verify_mode: 1 })
    end

    it "sets an ssl verify => true" do
      client = Booqable::Client.new(
        connection_options: { ssl: { verify: true } }
      )
      conn = client.send(:agent).instance_variable_get(:@conn)
      expect(conn.ssl[:verify]).to eq(true)
      expect(conn.ssl[:verify_mode]).to eq(OpenSSL::SSL::VERIFY_PEER)
    end

    it "sets an ssl verify => false" do
      client = Booqable::Client.new(
        connection_options: { ssl: { verify: false } }
      )
      conn = client.send(:agent).instance_variable_get(:@conn)
      expect(conn.ssl[:verify]).to eq(false)
      expect(conn.ssl[:verify_mode]).to eq(OpenSSL::SSL::VERIFY_NONE)
    end

    it "sets an ssl verify mode" do
      Booqable.configure do |config|
        config.ssl_verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      conn = Booqable.client.send(:agent).instance_variable_get(:@conn)
      expect(conn.ssl[:verify_mode]).to eq(OpenSSL::SSL::VERIFY_NONE)
    end

    it "ensures ssl verify mode is set to default when no override provided" do
      conn = Booqable.client.send(:agent).instance_variable_get(:@conn)
      expect(conn.ssl[:verify_mode]).to eq(OpenSSL::SSL::VERIFY_PEER)
    end

    it "passes along request headers for POST" do
      headers = { "X-Booqable-Foo" => "bar" }
      orders_request = stub_post("/orders")
                     .with(headers: headers)
                     .to_return(status: 201)
      client = Booqable::Client.new
      client.post "/orders", headers: headers
      assert_requested orders_request
      expect(client.last_response.status).to eq(201)
    end
  end

  describe "auto pagination", :vcr do
    before do
      Booqable.reset!
      Booqable.configure do |config|
        config.no_retries = true
        config.auto_paginate = true
        config.company = "demo"
        config.api_domain = "booqable.test"
        config.per_page = 1
      end
    end

    after do
      Booqable.reset!
    end

    it "fetches all the pages" do
      url = "/orders"
      Booqable.client.paginate url
      (1..3).each do |i|
        assert_requested :get, booqable_url("#{url}?page[number]=#{i}&page[size]=1&stats[total]=count")
      end
    end
  end

  context "error handling" do
    before do
      Booqable.reset!
      Booqable.configure do |config|
        config.no_retries = true
        config.company = "demo"
        config.api_domain = "booqable.test"
      end
      VCR.turn_off!
    end

    after do
      VCR.turn_on!
    end

    it "raises on 404" do
      stub_get("/booya").to_return(status: 404)
      expect { Booqable.get("/booya") }.to raise_error Booqable::NotFound
    end

    it "raises on 401" do
      stub_get("/unauthorized").to_return(status: 401)
      expect { Booqable.get("/unauthorized") }.to raise_error Booqable::Unauthorized
    end

    it "raises on 403" do
      stub_get("/forbidden").to_return(status: 403)
      expect { Booqable.get("/forbidden") }.to raise_error Booqable::Forbidden
    end

    it "raises on 405" do
      stub_get("/not_allowed").to_return(status: 405)
      expect { Booqable.get("/not_allowed") }.to raise_error Booqable::MethodNotAllowed
    end

    it "raises on 406" do
      stub_get("/not_acceptable").to_return(status: 406)
      expect { Booqable.get("/not_acceptable") }.to raise_error Booqable::NotAcceptable
    end

    it "raises on 409" do
      stub_get("/conflict").to_return(status: 409)
      expect { Booqable.get("/conflict") }.to raise_error Booqable::Conflict
    end

    it "raises on 410" do
      stub_get("/deprecated").to_return(status: 410)
      expect { Booqable.get("/deprecated") }.to raise_error Booqable::Deprecated
    end

    it "raises on 415" do
      stub_get("/unsupported").to_return(status: 415)
      expect { Booqable.get("/unsupported") }.to raise_error Booqable::UnsupportedMediaType
    end

    it "raises on 423" do
      stub_get("/locked").to_return(status: 423)
      expect { Booqable.get("/locked") }.to raise_error Booqable::Locked
    end

    it "raises on 429" do
      stub_get("/rate_limited").to_return(status: 429)
      expect { Booqable.get("/rate_limited") }.to raise_error Booqable::TooManyRequests
    end

    it "raises on 500" do
      stub_get("/boom").to_return(status: 500)
      expect { Booqable.get("/boom") }.to raise_error Booqable::InternalServerError
    end

    it "raises on 501" do
      stub_get("/not_implemented").to_return(status: 501)
      expect { Booqable.get("/not_implemented") }.to raise_error Booqable::NotImplemented
    end

    it "raises on 502" do
      stub_get("/bad_gateway").to_return(status: 502)
      expect { Booqable.get("/bad_gateway") }.to raise_error Booqable::BadGateway
    end

    it "raises on 503" do
      stub_get("/service_unavailable").to_return(status: 503)
      expect { Booqable.get("/service_unavailable") }.to raise_error Booqable::ServiceUnavailable
    end

    it "includes a message" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: {
            content_type: "application/json"
          },
          body: { message: "No order found for demo" }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.message).to include("GET http://demo.booqable.test/api/4/boom: 422 - No order found")
      end
    end

    it "includes an error" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: {
            content_type: "application/json"
          },
          body: { error: "No order found for demo" }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.message).to include("GET http://demo.booqable.test/api/4/boom: 422 - Error: No order found")
      end
    end

    it "includes an error summary" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: {
            content_type: "application/json"
          },
          body: {
            message: "Validation Failed",
            errors: [
              "Position is invalid",
              { resource: "Issue",
                field: "title",
                code: "missing_field" }
            ]
          }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.message).to include("GET http://demo.booqable.test/api/4/boom: 422 - Validation Failed")
        expect(e.message).to include("  Position is invalid")
        expect(e.message).to include("  resource: Issue")
        expect(e.message).to include("  field: title")
        expect(e.message).to include("  code: missing_field")
      end
    end

    it "exposes errors array" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: {
            content_type: "application/json"
          },
          body: {
            message: "Validation Failed",
            errors: [
              resource: "Issue",
              field: "title",
              code: "missing_field"
            ]
          }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.errors.first[:resource]).to eq("Issue")
        expect(e.errors.first[:field]).to eq("title")
        expect(e.errors.first[:code]).to eq("missing_field")
      end
    end

    it "exposes errors string" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: {
            content_type: "application/json"
          },
          body: {
            message: "Validation Failed",
            errors: "Issue"
          }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.message).to include("GET http://demo.booqable.test/api/4/boom: 422 - Validation Failed")
        expect(e.message).to include("Issue")
      end
    end

    it "handles errors as a hash" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: { content_type: "application/json" },
          body: {
            message: "Validation Failed",
            errors: { field: "some field", issue: "some issue" }
          }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.message).to include("GET http://demo.booqable.test/api/4/boom: 422 - Validation Failed")
        expect(e.message).to include("Error summary:")
        expect(e.message).to include('[:field, "some field"]')
        expect(e.message).to include('[:issue, "some issue"]')
      end
    end

    it "handles nil errors gracefully" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: { content_type: "application/json" },
          body: {
            message: "Validation Failed",
            errors: nil
          }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.message).to include("GET http://demo.booqable.test/api/4/boom: 422 - Validation Failed")
        expect(e.message).not_to include("Error summary:")
      end
    end

    it "handles errors array of strings" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: { content_type: "application/json" },
          body: {
            message: "Validation Failed",
            errors: [ "Issue 1", "Issue 2" ]
          }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.message).to include("GET http://demo.booqable.test/api/4/boom: 422 - Validation Failed")
        expect(e.message).to include("Error summary:")
        expect(e.message).to include("Issue 1")
        expect(e.message).to include("Issue 2")
      end
    end

    it "handles errors with special characters" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: { content_type: "application/json" },
          body: {
            message: "Validation Failed",
            errors: "Error with <special> characters & symbols"
          }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.message).to include("GET http://demo.booqable.test/api/4/boom: 422 - Validation Failed")
        expect(e.message).to include("Error summary:")
        expect(e.message).to include("Error with <special> characters & symbols")
      end
    end

    it "handles nested structures in errors" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: { content_type: "application/json" },
          body: {
            message: "Validation Failed",
            errors: [
              { field: "some field", issue: "some issue" },
              { details: { subfield: "value" } }
            ]
          }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.message).to include("GET http://demo.booqable.test/api/4/boom: 422 - Validation Failed")
        expect(e.message).to include("Error summary:")
        expect(e.message).to include("field: some field")
        expect(e.message).to include("issue: some issue")
        # Ruby, depending on the version, may format the hash differently
        # either with a ligature (=>) or a colon (:)
        # '{:subfield => "value"}' or '{subfield: "value"}'
        # so we use a regex to match either for the test assertion
        expect(e.message).to match(
          /details: \{(?::subfield\s*=>\s*"value"|subfield:\s*"value")\}/
        )
      end
    end

    it "handles mixed-type errors array" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: { content_type: "application/json" },
          body: {
            message: "Validation Failed",
            errors: [ "Issue", { field: "some field", issue: "some issue" } ]
          }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.message).to include("GET http://demo.booqable.test/api/4/boom: 422 - Validation Failed")
        expect(e.message).to include("Error summary:")
        expect(e.message).to include("Issue")
        expect(e.message).to include("field: some field")
        expect(e.message).to include("issue: some issue")
      end
    end

    it "knows the difference between different kinds of bad request" do
      stub_get("/some/admin/stuffs").to_return(status: 400)
      expect { Booqable.get("/some/admin/stuffs") }.to raise_error Booqable::BadRequest

      stub_get("/orders").to_return \
        status: 400,
        headers: {
          content_type: "application/json"
        },
        body: { code: "unwrittable_attribute" }.to_json
      expect { Booqable.get("/orders") }.to raise_error(Booqable::ReadOnlyAttribute)

      stub_get("/orders").to_return \
        status: 400,
        headers: {
          content_type: "application/json"
        },
        body: { code: "unknown_attribute" }.to_json
      expect { Booqable.get("/orders") }.to raise_error(Booqable::UnknownAttribute)

      stub_get("/orders").to_return \
        status: 400,
        headers: {
          content_type: "application/json"
        },
        body: { message: "extra fields should be an object" }.to_json
      expect { Booqable.get("/orders") }.to raise_error Booqable::ExtraFieldsInWrongFormat

      stub_get("/orders").to_return \
        status: 400,
        headers: {
          content_type: "application/json"
        },
        body: { message: "fields should be an object" }.to_json
      expect { Booqable.get("/orders") }.to raise_error Booqable::FieldsInWrongFormat

      stub_get("/orders").to_return \
        status: 400,
        headers: {
          content_type: "application/json"
        },
        body: { message: "page should be an object" }.to_json
      expect { Booqable.get("/orders") }.to raise_error Booqable::PageShouldBeAnObject

      stub_get("/orders").to_return \
        status: 400,
        headers: {
          content_type: "application/json"
        },
        body: { message: "failed typecasting" }.to_json
      expect { Booqable.get("/orders") }.to raise_error Booqable::FailedTypecasting

      stub_get("/orders").to_return \
        status: 400,
        headers: {
          content_type: "application/json"
        },
        body: { message: "invalid filter" }.to_json
      expect { Booqable.get("/orders") }.to raise_error Booqable::InvalidFilter

      stub_post("/orders").to_return \
        status: 400,
        headers: {
          content_type: "application/json"
        },
        body: { message: "required filter" }.to_json
      expect { Booqable.post("/orders") }.to raise_error Booqable::RequiredFilter
    end

    it "knows the difference between different kinds of payment required errors" do
      stub_get("/basic_payment").to_return(status: 402)
      expect { Booqable.get("/basic_payment") }.to raise_error Booqable::PaymentRequired

      stub_get("/feature").to_return \
        status: 402,
        headers: {
          content_type: "application/json"
        },
        body: { message: "feature_not_enabled" }.to_json
      expect { Booqable.get("/feature") }.to raise_error Booqable::FeatureNotEnabled

      stub_get("/trial").to_return \
        status: 402,
        headers: {
          content_type: "application/json"
        },
        body: { message: "trial_expired" }.to_json
      expect { Booqable.get("/trial") }.to raise_error Booqable::TrialExpired
    end

    it "knows the difference between different kinds of not found errors" do
      stub_get("/basic_not_found").to_return(status: 404)
      expect { Booqable.get("/basic_not_found") }.to raise_error Booqable::NotFound

      stub_get("/company").to_return \
        status: 404,
        headers: {
          content_type: "application/json"
        },
        body: { message: "company not found" }.to_json
      expect { Booqable.get("/company") }.to raise_error Booqable::CompanyNotFound
    end

    it "knows the difference between different kinds of service unavailable errors" do
      stub_get("/basic_unavailable").to_return(status: 503)
      expect { Booqable.get("/basic_unavailable") }.to raise_error Booqable::ServiceUnavailable

      stub_get("/readonly").to_return \
        status: 503,
        headers: {
          content_type: "application/json"
        },
        body: { message: "read-only mode enabled" }.to_json
      expect { Booqable.get("/readonly") }.to raise_error Booqable::ReadOnlyMode
    end

    it "knows the difference between different kinds of unprocessable entity" do
      stub_get("/some/admin/stuffs").to_return(status: 422)
      expect { Booqable.get("/some/admin/stuffs") }.to raise_error Booqable::UnprocessableEntity

      stub_post("/orders").to_return \
        status: 422,
        headers: {
          content_type: "application/json"
        },
        body: { message: "is not a datetime" }.to_json
      expect { Booqable.post("/orders") }.to raise_error Booqable::InvalidDateTimeFormat

      stub_post("/orders").to_return \
        status: 422,
        headers: {
          content_type: "application/json"
        },
        body: { message: "invalid date" }.to_json
      expect { Booqable.post("/orders") }.to raise_error Booqable::InvalidDateFormat
    end

    it "raises on unknown client errors" do
      stub_get("/orders").to_return \
        status: 418,
        headers: {
          content_type: "application/json"
        },
        body: { message: "I'm a teapot" }.to_json
      expect { Booqable.get("/orders") }.to raise_error Booqable::ClientError
    end

    it "raises on unknown server errors" do
      stub_get("/orders").to_return \
        status: 509,
        headers: {
          content_type: "application/json"
        },
        body: { message: "Bandwidth exceeded" }.to_json
      expect { Booqable.get("/orders") }.to raise_error Booqable::ServerError
    end

    it "resets last_response on errors" do
      stub_get("/booya").to_return(status: 200)
      stub_get("/orders").to_return \
        status: 509,
        headers: {
          content_type: "application/json"
        },
        body: { message: "Bandwidth exceeded" }.to_json

      client = Booqable.client
      client.get("/booya")
      expect(client.last_response).to_not be_nil
      expect { client.get("/orders") }.to raise_error Booqable::ServerError
      expect(client.last_response).to be_nil
    end

    it "handles an error response with an array body" do
      stub_get("/orders").to_return \
        status: 500,
        headers: {
          content_type: "application/json"
        },
        body: [].to_json
      expect { Booqable.get("/orders") }.to raise_error Booqable::ServerError
    end

    it "exposes the response status code" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: {
            content_type: "application/json"
          },
          body: { error: "No order found for demo" }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.response_status).to eql 422
      end
    end

    it "exposes the response headers" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: {
            content_type: "application/json"
          },
          body: { error: "No order found for demo" }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.response_headers).to eql({ "content-type" => "application/json" })
      end
    end

    it "exposes the response body" do
      stub_get("/boom")
        .to_return \
          status: 422,
          headers: {
            content_type: "application/json"
          },
          body: { error: "No order found for demo" }.to_json
      begin
        Booqable.get("/boom")
      rescue Booqable::UnprocessableEntity => e
        expect(e.response_body).to eql({ error: "No order found for demo" }.to_json)
      end
    end

    it "returns empty context when non rate limit error occurs" do
      stub_get("/user").to_return \
        status: 509,
        headers: {
          content_type: "application/json"
        },
        body: { message: "Bandwidth exceeded" }.to_json
      begin
        Booqable.get("/user")
      rescue Booqable::ServerError => e
        expect(e.context).to be_nil
      end
    end

    it "returns context with default data when rate limit error occurs but headers are missing" do
      stub_get("/user").to_return \
        status: 429,
        headers: {
          content_type: "application/json"
        },
        body: { message: "rate limit exceeded" }.to_json
      begin
        expect_any_instance_of(Faraday::Env).to receive(:headers).at_least(:once).and_return({})
        Booqable.get("/user")
      rescue Booqable::TooManyRequests => e
        expect(e.context).to be_an_instance_of(Booqable::RateLimit)
      end
    end

    it "returns context when non rate limit error occurs but rate limit headers are present" do
      stub_get("/user").to_return \
        status: 429,
        headers: {
          "content_type" => "application/json",
          "X-RateLimit-Limit" => 60,
          "X-RateLimit-Remaining" => 42,
          "X-RateLimit-Reset" => (Time.now + 60).to_i
        },
        body: { message: "rate limit exceeded" }.to_json
      begin
        Booqable.get("/user")
      rescue Booqable::TooManyRequests => e
        expect(e.context).to be_an_instance_of(Booqable::RateLimit)
        expect(e.context.limit).to eql 60
        expect(e.context.remaining).to eql 42
      end
    end

    it "returns context with default data when rate limit error occurs but headers are missing" do
      stub_get("/user").to_return \
        status: 429,
        headers: {
          content_type: "application/json"
        },
        body: { message: "You have exceeded a secondary rate limit." }.to_json
      begin
        Booqable.get("/user")
      rescue Booqable::TooManyRequests => e
        expect(e.context).to be_an_instance_of(Booqable::RateLimit)
      end
    end

    it "returns context when non rate limit error occurs but rate limit headers are present" do
      stub_get("/user").to_return \
        status: 429,
        headers: {
          "content_type" => "application/json",
          "X-RateLimit-Limit" => 60,
          "X-RateLimit-Remaining" => 42,
          "X-RateLimit-Reset" => (Time.now + 60).to_i
        },
        body: { message: "You have exceeded a secondary rate limit." }.to_json
      begin
        Booqable.get("/user")
      rescue Booqable::TooManyRequests => e
        expect(e.context).to be_an_instance_of(Booqable::RateLimit)
        expect(e.context.limit).to eql 60
        expect(e.context.remaining).to eql 42
      end
    end
  end

  describe "HTTP methods" do
    before do
      Booqable.reset!
      Booqable.configure do |config|
        config.api_domain = "booqable.test"
        config.company = "demo"
        config.api_version = "4"
      end
    end

    describe "PUT requests" do
      it "makes PUT requests using the put method" do
        orders_request = stub_put("/orders/123")
                       .with({
                               headers: { "Content-Type" => "application/vnd.api+json" }
                             })
                       .to_return(
                         status: 200,
                         headers: { "content-type" => "application/json" },
                         body: { data: { id: "123", type: "order" } }.to_json
                       )

        Booqable.client.put "/orders/123", { name: "Updated Order" }
        assert_requested orders_request
      end
    end

    describe "PATCH requests" do
      it "makes PATCH requests using the patch method" do
        orders_request = stub_patch("/orders/123")
                       .with({
                               headers: { "Content-Type" => "application/vnd.api+json" }
                             })
                       .to_return(
                         status: 200,
                         headers: { "content-type" => "application/json" },
                         body: { data: { id: "123", type: "order" } }.to_json
                       )

        Booqable.client.patch "/orders/123", { name: "Patched Order" }
        assert_requested orders_request
      end
    end

    describe "DELETE requests" do
      it "makes DELETE requests using the delete method" do
        orders_request = stub_delete("/orders/123")
                       .with({
                               headers: { "Content-Type" => "application/vnd.api+json" }
                             })
                       .to_return(
                         status: 204,
                         headers: { "content-type" => "application/json" },
                         body: ""
                       )

        Booqable.client.delete "/orders/123"
        assert_requested orders_request
      end
    end
  end

  describe "logging functionality" do
    it "initializes logger when debug mode is enabled" do
      client = Booqable::Client.new(
        api_domain: "booqable.test",
        company: "demo",
        api_key: test_api_key,
        debug: true
      )

      logger = client.send(:logger)
      expect(logger).to be_a(Logger)
      expect(logger.level).to eq(Logger::DEBUG)
    end

    it "returns nil for logger when debug mode is disabled" do
      client = Booqable::Client.new(
        api_domain: "booqable.test",
        company: "demo",
        api_key: test_api_key,
        debug: false
      )

      logger = client.send(:logger)
      expect(logger).to be_nil
    end
  end

  describe "convenience headers parsing" do
    it "parses convenience headers correctly" do
      client = Booqable::Client.new(
        api_domain: "booqable.test",
        company: "demo",
        api_key: test_api_key
      )

      options = {
        accept: "application/json",
        content_type: "application/json",
        user_agent: "Custom User Agent",
        other_param: "value"
      }

      parsed_options = client.send(:parse_options_with_convenience_headers, options)

      expect(parsed_options[:headers][:accept]).to eq("application/json")
      expect(parsed_options[:headers][:content_type]).to eq("application/json")
      expect(parsed_options[:headers][:user_agent]).to eq("Custom User Agent")
      expect(parsed_options[:query][:other_param]).to eq("value")
    end
  end

  describe "response encoding handling" do
    it "handles response encoding from charset in content-type header" do
      client = Booqable::Client.new(
        api_domain: "booqable.test",
        company: "demo",
        api_key: test_api_key
      )

      # Mock response with charset in content-type
      response_data = double("ResponseData")
      allow(response_data).to receive(:is_a?).with(String).and_return(true)
      allow(response_data).to receive(:force_encoding).with("utf-8").and_return(response_data)

      response = double("Response")
      allow(response).to receive(:headers).and_return({
        "content-type" => "application/json; charset=utf-8"
      })
      allow(response).to receive(:data).and_return(response_data)

      result = client.send(:response_data_with_correct_encoding, response)
      expect(result).to eq(response_data)
      expect(response_data).to have_received(:force_encoding).with("utf-8")
    end

    it "returns response data unchanged when no charset in content-type" do
      client = Booqable::Client.new(
        api_domain: "booqable.test",
        company: "demo",
        api_key: test_api_key
      )

      response_data = "test data without charset"
      response = double("Response")
      allow(response).to receive(:headers).and_return({
        "content-type" => "application/json"
      })
      allow(response).to receive(:data).and_return(response_data)

      result = client.send(:response_data_with_correct_encoding, response)
      expect(result).to eq(response_data)
    end

    it "returns response data unchanged when data is not a string" do
      client = Booqable::Client.new(
        api_domain: "booqable.test",
        company: "demo",
        api_key: test_api_key
      )

      response_data = { key: "value" }
      response = double("Response")
      allow(response).to receive(:headers).and_return({
        "content-type" => "application/json; charset=utf-8"
      })
      allow(response).to receive(:data).and_return(response_data)

      result = client.send(:response_data_with_correct_encoding, response)
      expect(result).to eq(response_data)
    end
  end

  describe "Booqable::Error" do
    describe "data method" do
      it "returns body when response body is not JSON" do
        response = {
          body: "plain text error message",
          response_headers: { content_type: "text/plain" }
        }

        error = Booqable::Error.new(response)
        expect(error.send(:data)).to eq("plain text error message")
      end

      it "returns body when response headers are missing" do
        response = {
          body: "error message without headers",
          response_headers: nil
        }

        error = Booqable::Error.new(response)
        expect(error.send(:data)).to eq("error message without headers")
      end
    end

    describe "response_message method" do
      it "returns data when data is a string" do
        response = {
          body: "string error message",
          response_headers: { content_type: "text/plain" }
        }

        error = Booqable::Error.new(response)
        expect(error.send(:response_message)).to eq("string error message")
      end

      it "returns message from hash when data is a hash" do
        response = {
          body: '{"message": "hash error message"}',
          response_headers: { content_type: "application/json" }
        }

        error = Booqable::Error.new(response)
        expect(error.send(:response_message)).to eq("hash error message")
      end

      it "returns nil when data is neither string nor hash" do
        response = {
          body: nil,
          response_headers: { content_type: "application/json" }
        }

        error = Booqable::Error.new(response)
        expect(error.send(:response_message)).to be_nil
      end
    end

    describe "#errors" do
      it "returns empty array when data is not a Hash" do
        # Test line 150 - else branch when data is not a Hash
        response = { body: "string error message", status: 400 }
        error = Booqable::Error.new(response)

        expect(error.errors).to eq([])
      end

      it "returns errors array when data is a Hash with errors" do
        response = {
          body: JSON.generate({ errors: [ { field: "name", message: "is required" } ] }),
          response_headers: { content_type: "application/json" },
          status: 422
        }
        error = Booqable::Error.new(response)

        expect(error.errors).to eq([ { field: "name", message: "is required" } ])
      end

      it "returns empty array when data is a Hash without errors" do
        response = {
          body: JSON.generate({ message: "Some error" }),
          response_headers: { content_type: "application/json" },
          status: 400
        }
        error = Booqable::Error.new(response)

        expect(error.errors).to eq([])
      end
    end

    describe "#redact_url" do
      it "redacts client_secret from URL" do
        # Test line 236 - gsub! when token is found in URL
        response = {
          method: :get,
          url: "https://api.example.com/test?client_secret=secret123&other_param=value",
          status: 400,
          body: "Error"
        }
        error = Booqable::Error.new(response)

        # Access the private method for testing
        redacted_url = error.send(:redact_url, response[:url].dup)

        expect(redacted_url).to include("client_secret=(redacted)")
        expect(redacted_url).not_to include("secret123")
      end

      it "redacts api_key from URL" do
        # Test line 236 - gsub! when token is found in URL
        response = {
          method: :get,
          url: "https://api.example.com/test?api_key=key456&other_param=value",
          status: 400,
          body: "Error"
        }
        error = Booqable::Error.new(response)

        redacted_url = error.send(:redact_url, response[:url].dup)

        expect(redacted_url).to include("api_key=(redacted)")
        expect(redacted_url).not_to include("key456")
      end

      it "handles URLs without sensitive tokens" do
        response = {
          method: :get,
          url: "https://api.example.com/test?param=value",
          status: 400,
          body: "Error"
        }
        error = Booqable::Error.new(response)

        redacted_url = error.send(:redact_url, response[:url].dup)

        expect(redacted_url).to eq("https://api.example.com/test?param=value")
      end

      it "redacts client_id from URL" do
        response = {
          method: :post,
          url: "https://api.example.com/oauth?client_id=id123&other_param=value",
          status: 400,
          body: "Error"
        }
        error = Booqable::Error.new(response)

        redacted_url = error.send(:redact_url, response[:url].dup)

        expect(redacted_url).to include("client_id=(redacted)")
        expect(redacted_url).not_to include("id123")
      end

      it "redacts refresh_token from URL" do
        response = {
          method: :post,
          url: "https://api.example.com/oauth?refresh_token=token456&other_param=value",
          status: 400,
          body: "Error"
        }
        error = Booqable::Error.new(response)

        redacted_url = error.send(:redact_url, response[:url].dup)

        expect(redacted_url).to include("refresh_token=(redacted)")
        expect(redacted_url).not_to include("token456")
      end
    end
  end

  describe "Booqable::UnsupportedAPIVersion" do
    it "has the correct error message" do
      # Test line 398 - super call in initialize
      expect { raise Booqable::UnsupportedAPIVersion.new }.to raise_error(
        Booqable::UnsupportedAPIVersion,
        "Unsupported API version configured. Only version '4' is supported."
      )
    end

    it "inherits from ConfigArgumentError" do
      error = Booqable::UnsupportedAPIVersion.new
      expect(error).to be_a(Booqable::ConfigArgumentError)
      expect(error).to be_a(ArgumentError)
    end
  end
end
