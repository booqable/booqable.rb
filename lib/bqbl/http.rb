module BQBL
  # HTTP request methods for {BQBL::Client}
  #
  # Provides low-level HTTP methods for making requests to the Booqable API.
  # Handles authentication, pagination, rate limiting, and response parsing.
  # All methods support both query parameters and request bodies as appropriate.
  #
  # @example Making a GET request
  #   client.get("/orders", include: "customer")
  #
  # @example Making a POST request with data
  #   client.post("/orders", data: { type: "order", attributes: { name: "New Order" } })
  #
  # @example Using pagination
  #   orders = client.paginate("/orders", page: { size: 50 })
  module HTTP
    # Headers that can be passed as top-level options for convenience
    CONVENIENCE_HEADERS = Set.new(%i[accept content_type user_agent])

    # Make a HTTP GET request
    #
    # @param url [String] The path, relative to {#api_endpoint}
    # @param options [Hash] Query and header params for request
    # @return [Sawyer::Resource]
    def get(url, options = {})
      request :get, url, options
    end

    # Make a HTTP post request
    #
    # @param url [String] The path, relative to {#api_endpoint}
    # @param options [Hash] Body and header params for request
    # @return [Sawyer::Resource]
    def post(url, options = {})
      request :post, url, options
    end

    # Make a HTTP put request
    #
    # @param url [String] The path, relative to {#api_endpoint}
    # @param options [Hash] Body and header params for request
    # @return [Sawyer::Resource]
    def put(url, options = {})
      request :put, url, options
    end

    # Make a HTTP patch request
    #
    # @param url [String] The path, relative to {#api_endpoint}
    # @param options [Hash] Body and header params for request
    # @return [Sawyer::Resource]
    def patch(url, options = {})
      request :patch, url, options
    end

    # Make a HTTP delete request
    #
    # @param url [String] The path, relative to {#api_endpoint}
    # @param options [Hash] Body and header params for request
    # @return [Sawyer::Resource]
    def delete(url, options = {})
      request :delete, url, options
    end

    # Make a HTTP head request
    #
    # @param url [String] The path, relative to {#api_endpoint}
    # @param options [Hash] Query and header params for request
    # @return [Sawyer::Resource]
    def head(url, options = {})
      request :head, url, options
    end

    # Make a HTTP request to the Booqable API
    #
    # Low-level request method that handles authentication, error handling,
    # and response processing. All other HTTP methods delegate to this method.
    #
    # @param method [Symbol] HTTP method (e.g. :get, :post, :put, :delete)
    # @param path [String] API endpoint path (e.g. "/products"), relative to {#api_endpoint}
    # @param data [Hash, String] Request body data (JSON or form-encoded)
    # @param options [Hash] Additional request options (headers, etc.)
    # @return [Sawyer::Resource] Response object with data and metadata
    # @raise [BQBL::Error] For API errors or HTTP failures
    #
    # @example Making a custom request
    #   client.request(:get, "/orders", { include: "customer" })
    def request(method, path, data, options = {})
      if data.is_a?(Hash) && options.empty?
        data[:headers] = default_headers.merge(data.delete(:headers) || {})

        if accept = data.delete(:accept)
          data[:headers][:accept] = accept
        end

        options = data.dup
      end

      options = parse_options_with_convenience_headers(options) if [ :get, :head ].include?(method)

      @last_response = response = agent.call(method, normalized_path(path), data, options)
      response_data_with_correct_encoding(response)
    rescue BQBL::Error => e
      @last_response = nil
      raise e
    end

    # Normalize a path to ensure it is a valid URL path
    #
    # Removes leading slashes and normalizes the path to prevent
    # directory traversal attacks and ensure consistent formatting.
    #
    # @param path [String] The path to normalize
    # @return [String] Normalized path without leading slash
    # @api private
    def normalized_path(path)
      relative_path = path.to_s.sub(%r{^/}, "") # Remove leading slash
      Addressable::URI.parse(relative_path.to_s).normalize.to_s
    end

    # Response for the last HTTP request
    #
    # @return [Sawyer::Response, nil] Last response object or nil if no request was made
    def last_response
      @last_response
    end

    # Make a paginated request to the Booqable API.
    #
    # @param url [String] The path, relative to {#api_endpoint}
    # @param options [Hash] Query and header params for request
    # @param block [Block] Block to perform the data concatination of the
    #   multiple requests. The block is called with two parameters, the first
    #   contains the contents of the requests so far and the second parameter
    #   contains the latest response.
    # @return [Sawyer::Resource]
    def paginate(url, options = {})
      if @per_page || @auto_paginate
        options[:page] ||= {}
        options[:page][:size] ||= @per_page || (@auto_paginate ? 25 : nil)
        options[:page][:number] ||= 1
        options[:stats] ||= { total: "count" } # otherwise we don't get the total count in the response
      end

      data = request(:get, url, options)[:data]

      if @auto_paginate
        # While there are more results to fetch, and we have not hit the rate limit
        while total_count = last_response_body[:meta][:stats][:total][:count] > data.length && rate_limit.remaining > 0
          options[:page][:number] = options[:page][:number] + 1

          request(:get, url, options.dup)

          data.concat(@last_response.data[:data]) if @last_response.data[:data].is_a?(Array)
        end
      end

      data
    end

    # Get rate limit information from the last response
    #
    # Extracts rate limiting information from the HTTP headers of the
    # most recent API response. This includes remaining requests, reset time,
    # and limit information.
    #
    # @return [RateLimit] Rate limit information object
    # @see RateLimit
    def rate_limit
      RateLimit.from_response(@last_response)
    end

    # Get or create the Faraday connection instance
    #
    # Returns a memoized Faraday connection configured with the appropriate
    # middleware stack, authentication, and connection options.
    #
    # @return [Faraday::Connection] HTTP connection instance
    # @api private
    def faraday
      @faraday ||= Faraday.new(faraday_options)
    end

    # Get default HTTP headers for requests
    #
    # Returns the standard headers that should be included with every
    # API request, including content type, accept headers, and user agent.
    #
    # @return [Hash] Default headers hash
    # @api private
    def default_headers
      {
        accept: default_media_type,
        content_type: default_media_type,
        user_agent: user_agent
      }
    end

    # Get Faraday connection options
    #
    # Builds the configuration hash for the Faraday connection including
    # URL, middleware builder, proxy settings, and SSL verification options.
    #
    # @return [Hash] Faraday connection options
    # @api private
    def faraday_options
      opts = connection_options ||  { headers: default_headers }

      opts[:url] = api_endpoint
      opts[:builder] = faraday_builder
      opts[:proxy] = proxy if proxy

      if opts[:ssl].nil?
        opts[:ssl] = { verify_mode: @ssl_verify_mode } if @ssl_verify_mode
      else
        verify = connection_options[:ssl][:verify]
        opts[:ssl] = {
          verify: verify,
          verify_mode: verify == false ? 0 : @ssl_verify_mode
        }
      end

      opts
    end

    # Get or create the Faraday middleware builder
    #
    # Creates a middleware stack with authentication and optionally removes
    # retry middleware based on configuration. The builder is memoized for
    # performance.
    #
    # @return [Faraday::RackBuilder] Middleware builder instance
    # @api private
    def faraday_builder
      @faraday_builder ||= @middleware.dup.tap do |builder|
        inject_auth_middleware(builder)
        # Remove retry middleware if no_retries is enabled
        if no_retries
          builder.handlers.delete_if { |handler| handler.klass == Faraday::Retry::Middleware }
        end
      end
    end

    # Get or create the Sawyer agent for API requests
    #
    # Returns a memoized Sawyer::Agent configured with the API endpoint,
    # serializer, and optional logging. Sawyer handles the low-level HTTP
    # communication and response parsing.
    #
    # @return [Sawyer::Agent] HTTP agent instance
    # @api private
    def agent
      @agent ||= Sawyer::Agent.new(api_endpoint,
                                   sawyer_options) do |agent|
         agent.response :logger, logger, bodies: true if logger
      end
    end

    # Get logger instance for debug output
    #
    # Creates a logger that outputs to STDOUT with DEBUG level when
    # debug mode is enabled. Returns nil when debug is disabled.
    #
    # @return [Logger, nil] Logger instance or nil if debug is disabled
    # @api private
    def logger
      @logger ||= Logger.new(STDOUT).tap do |logger|
        logger.level = Logger::DEBUG
      end if debug?
    end

    # Get configuration options for Sawyer agent
    #
    # Returns the configuration hash for the Sawyer agent including
    # the Faraday connection, link parser, and JSON:API serializer.
    #
    # @return [Hash] Sawyer agent configuration options
    # @api private
    def sawyer_options
      {
        faraday: faraday,
        # simple link parser
        link_parser: Sawyer::LinkParsers::Simple.new,
        # use our own JSON API serializer
        serializer: sawyer_serializer
      }
    end

    # Get the JSON:API serializer for Sawyer
    #
    # Returns the configured JSON:API serializer that handles encoding
    # and decoding of request/response bodies according to the JSON:API
    # specification.
    #
    # @return [BQBL::JsonApiSerializer] Serializer instance
    # @api private
    def sawyer_serializer
      BQBL::JsonApiSerializer.any_json
    end

    # Get the decoded body of the last response
    #
    # Parses the raw response body from the last HTTP request using
    # the JSON:API serializer. Returns nil if no response is available.
    #
    # @return [Hash, nil] Parsed response body or nil
    # @api private
    def last_response_body
      sawyer_serializer.decode(@last_response.body) if @last_response
    end

    # Parse options and extract convenience headers
    #
    # Processes request options to extract convenience headers (like accept,
    # content_type, user_agent) from the top level and moves them to the
    # headers hash for proper HTTP header handling.
    #
    # @param options [Hash] Request options that may contain convenience headers
    # @return [Hash] Processed options with headers properly organized
    # @api private
    def parse_options_with_convenience_headers(options)
      headers = options.delete(:headers) || {}

      CONVENIENCE_HEADERS.each do |h|
        if header = options.delete(h)
          headers[h] = header
        end
      end

      query = options.delete(:query) || {}

      opts = { query: options }
      opts[:query].merge!(query) if query.is_a?(Hash)
      opts[:headers] = headers unless headers.empty?
      opts
    end

    # Ensure response data has correct character encoding
    #
    # Reads the charset from the Content-Type header and forces the correct
    # encoding on string response data. Returns the response data unchanged
    # if no charset is specified or data is not a string.
    #
    # @param response [Sawyer::Response] HTTP response object
    # @return [Object] Response data with correct encoding
    # @api private
    def response_data_with_correct_encoding(response)
      content_type = response.headers.fetch("content-type", "")
      return response.data unless content_type.include?("charset") && response.data.is_a?(String)

      reported_encoding = content_type.match(/charset=([^ ]+)/)[1]
      response.data.force_encoding(reported_encoding)
    end

    # Get the full API endpoint URL
    #
    # Constructs the complete API endpoint URL from the configured company,
    # domain, protocol, and API version. Validates that the API version is
    # supported and that a company is specified.
    #
    # @return [String] Complete API endpoint URL
    # @raise [UnsupportedAPIVersion] If the API version is not supported
    # @raise [CompanyRequired] If no company is configured
    # @api private
    def api_endpoint
      @api_endpoint ||= begin
                          raise UnsupportedAPIVersion unless %w[4 boomerang].include?(api_version.to_s)
                          raise CompanyRequired if company.nil? || company.empty?
                          Addressable::URI.join("#{api_protocol}://#{company}.#{api_domain}/", "api/", api_version.to_s).to_s
                        end
    end
  end
end
