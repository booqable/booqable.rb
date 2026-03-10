# frozen_string_literal: true

module Booqable
  # Parses JSON:API payloads into Sawyer::Resource objects
  #
  # JSON:API formatted data (from webhooks or API responses) is converted
  # into Ruby objects with dot-notation access for convenient attribute access.
  #
  # @example Parse a JSON:API payload
  #   payload = '{"data":{"id":"123","type":"customers","attributes":{"name":"John"}}}'
  #   customer = Booqable::ResourceParser.parse(payload)
  #   customer.id   # => "123"
  #   customer.name # => "John"
  #
  # @example Parse with nested relationships
  #   payload = {
  #     "data" => {
  #       "id" => "123",
  #       "type" => "orders",
  #       "attributes" => { "status" => "reserved" },
  #       "relationships" => {
  #         "customer" => { "data" => { "id" => "456", "type" => "customers" } }
  #       }
  #     },
  #     "included" => [
  #       { "id" => "456", "type" => "customers", "attributes" => { "name" => "John" } }
  #     ]
  #   }
  #   order = Booqable::ResourceParser.parse(payload)
  #   order.customer.name # => "John"
  #
  class ResourceParser
    # Parse a JSON:API payload into a Sawyer::Resource
    #
    # @param payload [String, Hash] JSON:API payload (string or parsed hash)
    # @return [Sawyer::Resource, nil] Parsed resource object with dot-notation access,
    #   or nil for empty/nil input
    def self.parse(payload)
      new(payload).parse
    end

    # Initialize a new ResourceParser
    #
    # @param payload [String, Hash] JSON:API payload
    def initialize(payload)
      @payload = payload
    end

    # Parse the payload into a Sawyer::Resource
    #
    # @return [Sawyer::Resource, nil] Parsed resource or nil for empty input
    def parse
      return nil if @payload.nil?

      json_string = @payload.is_a?(String) ? @payload : @payload.to_json
      return nil if json_string.strip.empty?

      serializer = JsonApiSerializer.any_json
      decoded = serializer.decode(json_string)

      return nil unless decoded && decoded[:data]

      Sawyer::Resource.new(sawyer_agent, decoded[:data])
    end

    private

    # Create a minimal Sawyer agent for wrapping resources
    #
    # The agent URL is a placeholder - we don't make any HTTP requests.
    # We just need the agent to create Sawyer::Resource objects that
    # provide dot-notation attribute access.
    #
    # @return [Sawyer::Agent]
    def sawyer_agent
      @sawyer_agent ||= Sawyer::Agent.new("https://example.com") do |http|
        http.headers[:content_type] = "application/json"
      end
    end
  end
end
