# frozen_string_literal: true

module Booqable
  # Client for the Booqable API
  #
  # Provides a Ruby interface to interact with the Booqable rental management API.
  # The client can be configured with various authentication methods including
  # API keys, OAuth, and single-use tokens.
  #
  # @example Initialize with API key
  #   client = Booqable::Client.new(
  #     api_key: "your_api_key",
  #     company: "your_company"
  #   )
  #
  # @example Initialize with OAuth
  #   client = Booqable::Client.new(
  #     client_id: "your_client_id",
  #     client_secret: "your_client_secret",
  #     company: "your_company"
  #   )
  #
  # @see https://developers.booqable.com/
  class Client
    include Booqable::Configurable
    include Booqable::Resources
    include Booqable::Auth
    include Booqable::HTTP

    # List of configuration keys that contain sensitive information
    # and should be masked in inspect output
    SECRETS = %w[
      client_secret
      client_id
      api_key
      single_use_token
      single_use_token_private_key
      single_use_token_secret
      refresh_token
      access_token
    ]

    # Initialize a new Client
    #
    # @param options [Hash] Configuration options for the client
    # @see Booqable::Configurable For a complete list of supported configuration options
    def initialize(options = {})
      # Use options passed in, but fall back to module defaults
      #
      # This may look like a `.keys.each` which should be replaced with `#each_key`, but
      # this doesn't actually work, since `#keys` is just a method we've defined ourselves.
      # The class doesn't fulfill the whole `Enumerable` contract.
      Booqable::Configurable.keys.each do |key|
        value = options[key].nil? ? Booqable.instance_variable_get(:"@#{key}") : options[key]
        instance_variable_set(:"@#{key}", value)
      end
    end

    # String representation of the client with sensitive information masked
    #
    # Overrides the default inspect method to hide sensitive configuration
    # values like API keys, client secrets, and tokens by replacing them
    # with asterisks.
    #
    # @return [String] String representation with secrets masked
    # @example
    #   client = Booqable::Client.new(api_key: "secret123")
    #   client.inspect #=> "#<Booqable::Client:0x... @api_key=\"*********\">"
    def inspect
      inspected = super

      secrets = SECRETS.map { |secret| instance_variable_get("@#{secret}") }

      inspected.gsub!(/"(#{secrets.join("|")})"/) do |match|
        match.gsub!(/./, "*")
      end

      inspected
    end
  end
end
