module BQBL
  # Resource-related methods for {BQBL::Client}
  #
  # This module dynamically defines methods for each resource listed in the
  # `resources.json` file. Each resource method returns a {ResourceProxy} that
  # provides standard CRUD operations for that resource type.
  #
  # The resources.json file can contain either simple strings or hash mappings
  # for aliases. For example:
  #
  # @example resources.json structure
  #   [
  #     "orders",
  #     "customers",
  #     { "order_status_transitions": "transitions" }
  #   ]
  #
  # This would define the following methods on {BQBL::Client}:
  # - `orders` - returns ResourceProxy for orders
  # - `customers` - returns ResourceProxy for customers
  # - `order_status_transitions` - returns ResourceProxy for order_status_transitions
  # - `transitions` - alias for order_status_transitions
  #
  # @example Using resource methods
  #   client = BQBL::Client.new
  #
  #   # Access orders resource
  #   orders = client.orders
  #   all_orders = orders.list
  #
  #   # Access customers resource
  #   customers = client.customers
  #   customer = customers.find("123")
  #
  #   # Access order status transitions directly
  #   order_status_transitions = client.order_status_transitions
  #
  #   # Access order status transitions with alias
  #   transitions = client.transitions
  #
  # @see ResourceProxy
  module Resources
    # Path to the resources definition file
    RESOURCES_FILE_PATH = File.join(File.dirname(__FILE__), "resources.json")

    # All resources loaded from the resources.json file
    ALL_RESOURCES = JSON.parse(File.read(RESOURCES_FILE_PATH))

    ALL_RESOURCES.each do |resource|
      resource_name = resource.is_a?(Hash) ? resource.keys.first : resource
      resource_alias = resource.is_a?(Hash) ? resource.values.first : nil

      # Dynamically define resource method
      # @return [ResourceProxy] Resource proxy for the specified resource
      define_method(resource_name) do
        ResourceProxy.new(self, resource_name)
      end

      next unless resource_alias

      # Dynamically define resource alias method
      # @return [ResourceProxy] Resource proxy for the specified resource
      define_method(resource_alias) do
        ResourceProxy.new(self, resource_name)
      end
    end
  end
end
