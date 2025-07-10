# frozen_string_literal: true

module BQBL
  # Generic resource proxy for API collections
  #
  # Provides a uniform interface for interacting with API resources using
  # standard CRUD operations. Each resource proxy handles the JSON:API
  # formatting and delegates HTTP requests to the underlying client.
  #
  # @example Working with orders
  #   orders = BQBL::ResourceProxy.new(client, "orders")
  #
  #   # Of course, you can also just use BQBL.orders directly.
  #
  #   # List all orders
  #   all_orders = orders.list
  #
  #   # Find a specific order
  #   order = orders.find("123")
  #
  #   # Create a new order
  #   new_order = orders.create(starts_at: "2024-01-01T00:00:00Z", stops_at: "2024-01-02T00:00:00Z", status: "draft")
  #
  #   # Update an existing order
  #   updated_order = orders.update("123", status: "reserved")
  class ResourceProxy
    # Initialize a new resource proxy
    #
    # @param client [BQBL::Client] The client instance to use for requests
    # @param resource_name [String, Symbol] The name of the resource (e.g., "orders", "customers")
    def initialize(client, resource_name)
      @client = client
      @resource = resource_name.to_s
    end

    # List all resources
    #
    # Retrieves a collection of resources with optional filtering and pagination.
    # Uses the JSON:API specification for query parameters.
    #
    # @param params [Hash] Query parameters for filtering, sorting, and pagination
    # @option params [String] :include Related resources to include (e.g., "customer,items")
    # @option params [Hash] :filter Filter criteria (e.g., { status: "active" })
    # @option params [String] :sort Sort criteria (e.g., "created_at", "-updated_at")
    # @option params [Hash] :page Pagination parameters (e.g., { number: 1, size: 25 })
    # @return [Array, Enumerator] Collection of resources or enumerator for auto-pagination
    #
    # @example List orders with filters
    #   orders.list(
    #     include: "customer",
    #     filter: { status: "active" },
    #     sort: "-created_at"
    #   )
    def list(params = {})
      paginate @resource, params
    end

    # Find a specific resource by ID
    #
    # Retrieves a single resource by its unique identifier.
    #
    # @param id [String, Integer] The unique identifier of the resource
    # @param params [Hash] Additional query parameters
    # @option params [String] :include Related resources to include
    # @return [Hash] The resource data
    # @raise [BQBL::NotFound] If the resource doesn't exist
    #
    # @example Find an order by ID
    #   order = orders.find("123", include: "customer,items")
    def find(id, params = {})
      response = request :get, "#{@resource}/#{id}", params
      response.data
    end

    # Create a new resource
    #
    # Creates a new resource with the provided attributes using JSON:API format.
    #
    # @param attrs [Hash] Attributes for the new resource
    # @return [Hash] The created resource data
    # @raise [BQBL::UnprocessableEntity] If validation fails
    #
    # @example Create a new order
    #   new_order = orders.create(
    #     starts_at: "2024-01-01T00:00:00Z",
    #     stops_at: "2024-01-02T00:00:00Z",
    #     status: "draft"
    #   )
    def create(attrs = {})
      response = request :post, @resource, { data: { type: @resource, attributes: attrs } }
      response.data
    end

    # Update an existing resource
    #
    # Updates a resource with the provided attributes using JSON:API format.
    #
    # @param id [String, Integer] The unique identifier of the resource to update
    # @param attrs [Hash] Attributes to update
    # @return [Hash] The updated resource data
    # @raise [BQBL::NotFound] If the resource doesn't exist
    # @raise [BQBL::UnprocessableEntity] If validation fails
    #
    # @example Update an order
    #   updated_order = orders.update("123", status: "reserved")
    def update(id, attrs = {})
      response = request :put, "#{@resource}/#{id}", { data: { type: @resource, id: id, attributes: attrs } }
      response.data
    end

    private

    attr_reader :client

    # Delegate request method to client
    #
    # @param args [Array] Arguments to pass to client.request
    # @return [Object] Response from client.request
    def request(...)
      client.request(...)
    end

    # Delegate paginate method to client
    #
    # @param args [Array] Arguments to pass to client.paginate
    # @return [Object] Response from client.paginate
    def paginate(...)
      client.paginate(...)
    end
  end
end
