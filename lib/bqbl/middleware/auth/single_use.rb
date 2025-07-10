module BQBL
  module Middleware
    module Auth
      # Faraday middleware for single-use JWT token authentication
      #
      # This middleware generates and adds single-use JWT tokens for authentication.
      # Each token is unique per request and includes request-specific data like
      # method, path, and body hash to prevent replay attacks.
      #
      # Supports multiple JWT algorithms: HS256 (HMAC), RS256 (RSA), and ES256 (ECDSA).
      #
      # For more info see: https://developers.booqable.com/#authentication-request-signing
      #
      # @example Adding to Faraday middleware stack
      #   builder.use BQBL::Middleware::Auth::SingleUse,
      #     single_use_token: "token_id",
      #     single_use_token_algorithm: "HS256",
      #     single_use_token_private_key: "secret_key",
      #     single_use_token_company_id: "company_uuid",
      #     single_use_token_user_id: "user_uuid",
      #     api_endpoint: "https://company.booqable.com/api/4"
      class SingleUse < Base
        # Token kind identifier for JWT header
        KIND = "single_use"

        # Default domain for issuer URL construction
        BOOQABLE_DOMAIN = "booqable.com"

        # Initialize the single-use token authentication middleware
        #
        # @param app [#call] The next middleware in the Faraday stack
        # @param options [Hash] Configuration options
        # @option options [String] :single_use_token Token identifier (kid)
        # @option options [String] :single_use_token_algorithm JWT algorithm (HS256, RS256, ES256)
        # @option options [Integer] :single_use_token_expiration_period Token expiration in seconds (default: 600)
        # @option options [String] :single_use_token_company_id Company UUID for audience claim
        # @option options [String] :single_use_token_user_id User UUID for subject claim
        # @option options [String] :single_use_token_private_key Private key or secret for signing
        # @option options [String] :api_endpoint API endpoint URL for issuer determination
        # @raise [SingleUseTokenAlgorithmRequired] If algorithm is not provided
        # @raise [SingleUseTokenCompanyIdRequired] If company ID is not provided
        # @raise [SingleUseTokenUserIdRequired] If user ID is not provided
        # @raise [PrivateKeyOrSecretRequired] If private key/secret is not provided
        def initialize(app, options = {})
          super(app)

          @kid = options.fetch(:single_use_token)
          @alg = options.fetch(:single_use_token_algorithm) || raise(SingleUseTokenAlgorithmRequired)
          @exp = options.fetch(:single_use_token_expiration_period, Time.now.to_i + 10 * 60)
          @aud = options.fetch(:single_use_token_company_id) || raise(SingleUseTokenCompanyIdRequired)
          @sub = options.fetch(:single_use_token_user_id) || raise(SingleUseTokenUserIdRequired)
          @raw_private_key = options.fetch(:single_use_token_private_key) || raise(PrivateKeyOrSecretRequired)
          @api_endpoint = options.fetch(:api_endpoint, nil)

          @private_key = private_key
        end

        # Process the HTTP request and add single-use token authentication
        #
        # Generates a unique JWT token for this specific request and adds it
        # to the Authorization header. Then passes the request to the next
        # middleware in the stack.
        #
        # @param env [Faraday::Env] The request environment
        # @return [Faraday::Response] The response from the next middleware
        def call(env)
          env.request_headers["Authorization"] ||= "Bearer #{generate_token(env)}"

          @app.call(env)
        end

        private

        # Generate a JWT token for the current request
        #
        # @param env [Faraday::Env] The request environment
        # @return [String] Encoded JWT token
        def generate_token(env)
          JWT.encode generate_payload(env), @private_key, @alg, headers
        end

        # Generate the JWT payload with request-specific claims
        #
        # @param env [Faraday::Env] The request environment
        # @return [Hash] JWT payload with standard and custom claims
        def generate_payload(env)
          data = generate_data(env)

          request_id = SecureRandom.respond_to?(:uuid_v4) ? SecureRandom.uuid_v4 : SecureRandom.uuid

          {
            alg: @alg,
            iat: Time.now.to_i,
            exp: Time.now.to_i + @exp,
            aud: @aud,
            sub: @sub,
            iss: iss,
            jti: "#{request_id}.#{data}"
          }
        end

        # Generate JWT headers
        #
        # @return [Hash] JWT headers with key ID and kind
        def headers
          { kid: @kid, kind: KIND }
        end

        # Generate request-specific data hash for the JWT
        #
        # Creates a hash from the HTTP method, full path, and body content
        # to ensure each token is unique to the specific request being made.
        #
        # @param env [Faraday::Env] The request environment
        # @return [String] Base64-encoded SHA256 hash of request data
        def generate_data(env)
          request_method = env.method.to_s.upcase
          fullpath = env.url.request_uri
          body = env.body
          encoded_body = body ? Base64.strict_encode64(::OpenSSL::Digest::SHA256.new(body).digest) : nil

          Base64.strict_encode64(
            ::OpenSSL::Digest::SHA256.new([ request_method, fullpath, encoded_body ].join(".")).digest
          )
        end

        # Generate the issuer URL for the JWT
        #
        # @return [String] Issuer URL based on the API endpoint
        def iss
          "https://#{slug}.#{BOOQABLE_DOMAIN}"
        end

        # Extract the company slug from the API endpoint
        #
        # @return [String] Company identifier from the hostname
        def slug
          Addressable::URI.parse(@api_endpoint).host.split(".").first
        end

        # Parse the private key based on the configured algorithm
        #
        # @return [OpenSSL::PKey::EC, OpenSSL::PKey::RSA, String] Parsed private key
        def private_key
          case @alg
          when "ES256"
            OpenSSL::PKey::EC.new(@raw_private_key)
          when "RS256"
            OpenSSL::PKey::RSA.new(@raw_private_key)
          when "HS256"
            @raw_private_key
          end
        end
      end
    end
  end
end
