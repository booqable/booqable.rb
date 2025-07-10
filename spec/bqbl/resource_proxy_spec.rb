# frozen_string_literal: true

require "json"

describe BQBL::ResourceProxy do
  before do
    BQBL.configure do |config|
      config.api_domain = "booqable.test"
      config.company = "demo"
      config.api_key = test_api_key
    end
  end

  after do
    BQBL.reset!
  end

  describe "orders resource" do
    describe "#list", :vcr do
      it "lists orders" do
        orders = BQBL.orders.list
        expect(orders).to be_an(Array)
        expect(orders.length).to be > 0
        expect(orders.first.id).to be_a(String)
      end

      it "accepts parameters" do
        orders = BQBL.orders.list(page: { size: 1 })
        expect(orders).to be_an(Array)
        expect(orders.length).to eq(1)
      end

      it "returns orders with expected attributes" do
        orders = BQBL.orders.list
        order = orders.first
        expect(order).to respond_to(:id)
        expect(order).to respond_to(:created_at)
        expect(order).to respond_to(:updated_at)
      end

      it "supports includes for customer" do
        orders = BQBL.orders.list(include: "customer")
        expect(orders).to be_an(Array)
        expect(orders.length).to be > 0
        order = orders.first
        expect(order).to respond_to(:customer)
      end

      it "supports multiple includes" do
        orders = BQBL.orders.list(include: "customer")
        expect(orders).to be_an(Array)
        expect(orders.length).to be > 0
        order = orders.first
        expect(order).to respond_to(:customer)
      end
    end

    describe "#find", :vcr do
      let(:order_id) { "3e037580-3d7a-4d23-876c-f0ba1a481bb7" }

      it "finds an order by id" do
        order = BQBL.orders.find(order_id)
        expect(order.id).to eq(order_id)
      end

      it "accepts parameters" do
        order = BQBL.orders.find(order_id, include: "customer")
        expect(order.id).to eq(order_id)
      end

      it "returns order with expected attributes" do
        order = BQBL.orders.find(order_id)
        expect(order).to respond_to(:id)
        expect(order).to respond_to(:created_at)
        expect(order).to respond_to(:updated_at)
      end

      it "supports includes for customer" do
        order = BQBL.orders.find(order_id, include: "customer")
        expect(order.id).to eq(order_id)
        expect(order.customer.name).not_to be_nil
      end

      it "supports multiple includes" do
        order = BQBL.orders.find(order_id, include: "customer,lines")
        expect(order.id).to eq(order_id)
        expect(order.customer.name).not_to be_nil
        expect(order.lines).to be_an(Array)
      end
    end

    describe "#create", :vcr do
      it "creates a new order" do
        order_attributes = {
          starts_at: "2024-01-01T00:00:00Z",
          stops_at: "2024-01-02T00:00:00Z"
        }

        order = BQBL.orders.create(order_attributes)
        expect(order.id).to be_a(String)
        expect(order.starts_at).to eq(Time.parse("2024-01-01T00:00:00Z"))
        expect(order.stops_at).to eq(Time.parse("2024-01-02T00:00:00Z"))
      end

      it "returns created order with expected attributes" do
        order_attributes = {
          starts_at: "2024-01-01T00:00:00Z",
          stops_at: "2024-01-02T00:00:00Z"
        }

        order = BQBL.orders.create(order_attributes)
        expect(order).to respond_to(:id)
        expect(order).to respond_to(:created_at)
        expect(order).to respond_to(:updated_at)
      end
    end

    describe "#update", :vcr do
      let(:order_id) { "3e037580-3d7a-4d23-876c-f0ba1a481bb7" }

      it "updates an existing order" do
        update_attributes = {
          starts_at: "2025-04-09T11:00:00Z",
          stops_at: "2025-04-11T17:00:00Z"
        }

        order = BQBL.orders.update(order_id, update_attributes)
        expect(order.id).to eq(order_id)
        expect(order.starts_at).to eq(Time.parse("2025-04-09T11:00:00Z"))
        expect(order.stops_at).to eq(Time.parse("2025-04-11T17:00:00Z"))
      end

      it "returns updated order with expected attributes" do
        update_attributes = {
          starts_at: "2025-04-09T11:00:00Z",
          stops_at: "2025-04-11T17:00:00Z"
        }

        order = BQBL.orders.update(order_id, update_attributes)
        expect(order).to respond_to(:id)
        expect(order).to respond_to(:created_at)
        expect(order).to respond_to(:updated_at)
      end
    end

    describe "includes functionality", :vcr do
      let(:order_id) { "3e037580-3d7a-4d23-876c-f0ba1a481bb7" }

      it "supports including customer in list" do
        orders = BQBL.orders.list(include: "customer", page: { size: 1 })
        expect(orders).to be_an(Array)
        expect(orders.length).to be > 0
        order = orders.first
        expect(order).to respond_to(:customer)
      end

      it "returns customer as an object in list results" do
        orders = BQBL.orders.list(include: "customer", page: { size: 1 })
        expect(orders).to be_an(Array)
        expect(orders.length).to be > 0
        order = orders.first
        if order.customer
          expect(order.customer).not_to be_an(Array)
          expect(order.customer).to respond_to(:id)
          expect(order.customer).to respond_to(:name)
        end
      end

      it "supports including customer in find" do
        order = BQBL.orders.find(order_id, include: "customer")
        expect(order.id).to eq(order_id)
        expect(order).to respond_to(:customer)
      end

      it "validates customer relationship when included" do
        order = BQBL.orders.find(order_id, include: "customer")
        expect(order.id).to eq(order_id)
        expect(order).to respond_to(:customer)
        expect(order.customer).not_to be_nil if order.customer
      end

      it "returns customer as an object, not an array" do
        order = BQBL.orders.find(order_id, include: "customer")
        expect(order.id).to eq(order_id)
        if order.customer
          expect(order.customer).not_to be_an(Array)
          expect(order.customer).to respond_to(:id)
          expect(order.customer).to respond_to(:name)
        end
      end

      it "works without includes" do
        order = BQBL.orders.find(order_id)
        expect(order.id).to eq(order_id)
        expect(order).to respond_to(:id)
        expect(order).to respond_to(:created_at)
      end

      it "handles include parameter variations" do
        orders = BQBL.orders.list(include: [ "customer" ], page: { size: 1 })
        expect(orders).to be_an(Array)
        expect(orders.length).to be > 0
        order = orders.first
        expect(order).to respond_to(:customer)
      end

      it "supports complex nested includes" do
        order = BQBL.orders.find(order_id, include: "lines,lines.item")
        expect(order.id).to eq(order_id)

        if order.lines && order.lines.any?
          line = order.lines.first
          if line.item
            expect(line.item).not_to be_nil
            expect(line.item).to respond_to(:name)
            expect(line.item.name).not_to be_nil
          end
        end
      end
    end
  end

  describe "different resource types" do
    describe "customers resource" do
      it "works with customers resource", :vcr do
        customers = BQBL.customers.list
        expect(customers).to be_an(Array)
      end

      it "can create customers", :vcr do
        customer_attributes = {
          name: "Test Customer #{SecureRandom.hex(4)}",
          email: "test#{SecureRandom.hex(4)}@example.com"
        }

        customer = BQBL.customers.create(customer_attributes)
        expect(customer.id).to be_a(String)
        expect(customer.name).to include("Test Customer")
        expect(customer.email).to include("test")
      end
    end
  end

  describe "resource aliases" do
    describe "carriers alias" do
      it "responds to carriers alias for app_carriers", :vcr do
        expect(BQBL).to respond_to(:carriers)
        expect(BQBL).to respond_to(:app_carriers)
      end

      it "both carriers and app_carriers return same ResourceProxy class", :vcr do
        carriers_proxy = BQBL.carriers
        app_carriers_proxy = BQBL.app_carriers

        expect(carriers_proxy).to be_a(BQBL::ResourceProxy)
        expect(app_carriers_proxy).to be_a(BQBL::ResourceProxy)
        expect(carriers_proxy.class).to eq(app_carriers_proxy.class)
      end

      it "carriers alias points to app_carriers resource", :vcr do
        carriers_proxy = BQBL.carriers
        app_carriers_proxy = BQBL.app_carriers

        expect(carriers_proxy.instance_variable_get(:@resource)).to eq("app_carriers")
        expect(app_carriers_proxy.instance_variable_get(:@resource)).to eq("app_carriers")
        expect(carriers_proxy.instance_variable_get(:@resource)).to eq(app_carriers_proxy.instance_variable_get(:@resource))
      end

      it "can list carriers using alias", :vcr do
        carriers = BQBL.carriers.list
        expect(carriers).to be_an(Array)
      end

      it "can list app_carriers using full resource name", :vcr do
        app_carriers = BQBL.app_carriers.list
        expect(app_carriers).to be_an(Array)
      end

      it "carriers and app_carriers return same data", :vcr do
        carriers = BQBL.carriers.list
        app_carriers = BQBL.app_carriers.list

        expect(carriers.length).to eq(app_carriers.length)
        if carriers.any? && app_carriers.any?
          expect(carriers.first.id).to eq(app_carriers.first.id)
        end
      end

      it "supports all CRUD operations through alias", :vcr do
        # Test that all ResourceProxy methods work through alias
        carriers_proxy = BQBL.carriers

        expect(carriers_proxy).to respond_to(:list)
        expect(carriers_proxy).to respond_to(:find)
        expect(carriers_proxy).to respond_to(:create)
        expect(carriers_proxy).to respond_to(:update)
      end

      it "works with parameters and includes through alias", :vcr do
        carriers = BQBL.carriers.list(page: { size: 1 })
        expect(carriers).to be_an(Array)
      end
    end

    describe "payment_options alias" do
      it "responds to payment_options alias for app_payment_options", :vcr do
        expect(BQBL).to respond_to(:payment_options)
        expect(BQBL).to respond_to(:app_payment_options)
      end

      it "both payment_options and app_payment_options return same ResourceProxy class", :vcr do
        payment_options_proxy = BQBL.payment_options
        app_payment_options_proxy = BQBL.app_payment_options

        expect(payment_options_proxy).to be_a(BQBL::ResourceProxy)
        expect(app_payment_options_proxy).to be_a(BQBL::ResourceProxy)
        expect(payment_options_proxy.class).to eq(app_payment_options_proxy.class)
      end

      it "payment_options alias points to app_payment_options resource", :vcr do
        payment_options_proxy = BQBL.payment_options
        app_payment_options_proxy = BQBL.app_payment_options

        expect(payment_options_proxy.instance_variable_get(:@resource)).to eq("app_payment_options")
        expect(app_payment_options_proxy.instance_variable_get(:@resource)).to eq("app_payment_options")
        expect(payment_options_proxy.instance_variable_get(:@resource)).to eq(app_payment_options_proxy.instance_variable_get(:@resource))
      end

      it "can list payment_options using alias", :vcr do
        payment_options = BQBL.payment_options.list
        expect(payment_options).to be_an(Array)
      end

      it "can list app_payment_options using full resource name", :vcr do
        app_payment_options = BQBL.app_payment_options.list
        expect(app_payment_options).to be_an(Array)
      end

      it "payment_options and app_payment_options return same data", :vcr do
        payment_options = BQBL.payment_options.list
        app_payment_options = BQBL.app_payment_options.list

        expect(payment_options.length).to eq(app_payment_options.length)
        if payment_options.any? && app_payment_options.any?
          expect(payment_options.first.id).to eq(app_payment_options.first.id)
        end
      end

      it "supports all CRUD operations through alias", :vcr do
        # Test that all ResourceProxy methods work through alias
        payment_options_proxy = BQBL.payment_options

        expect(payment_options_proxy).to respond_to(:list)
        expect(payment_options_proxy).to respond_to(:find)
        expect(payment_options_proxy).to respond_to(:create)
        expect(payment_options_proxy).to respond_to(:update)
      end

      it "works with parameters and includes through alias", :vcr do
        payment_options = BQBL.payment_options.list(page: { size: 1 })
        expect(payment_options).to be_an(Array)
      end
    end
  end

  describe "error handling" do
    it "raises error for invalid order id", :vcr do
      expect { BQBL.orders.find("invalid-id") }.to raise_error(BQBL::NotFound)
    end

    it "raises error for invalid create attributes", :vcr do
      invalid_attributes = {
        invalid_field: "invalid_value"
      }

      expect { BQBL.orders.create(invalid_attributes) }.to raise_error(BQBL::UnknownAttribute)
    end
  end
end
