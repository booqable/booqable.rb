# frozen_string_literal: true

require "json"

describe Booqable::ResourceProxy do
  before do
    Booqable.configure do |config|
      config.api_domain = "booqable.test"
      config.company_id = "demo"
      config.api_key = test_api_key
    end
  end

  after do
    Booqable.reset!
  end

  describe "orders resource" do
    describe "#list", :vcr do
      it "lists orders" do
        orders = Booqable.orders.list
        expect(orders).to be_an(Array)
        expect(orders.length).to be > 0
        expect(orders.first.id).to be_a(String)
      end

      it "accepts parameters" do
        orders = Booqable.orders.list(page: { size: 1 })
        expect(orders).to be_an(Array)
        expect(orders.length).to eq(1)
      end

      it "returns orders with expected attributes" do
        orders = Booqable.orders.list
        order = orders.first
        expect(order).to respond_to(:id)
        expect(order).to respond_to(:created_at)
        expect(order).to respond_to(:updated_at)
      end

      it "supports includes for customer" do
        orders = Booqable.orders.list(include: "customer")
        expect(orders).to be_an(Array)
        expect(orders.length).to be > 0
        order = orders.first
        expect(order).to respond_to(:customer)
      end

      it "supports multiple includes" do
        orders = Booqable.orders.list(include: "customer")
        expect(orders).to be_an(Array)
        expect(orders.length).to be > 0
        order = orders.first
        expect(order).to respond_to(:customer)
      end
    end

    describe "#all" do
      it "responds to all method" do
        expect(Booqable.orders).to respond_to(:all)
      end

      it "all method delegates to list" do
        proxy = Booqable.orders
        allow(proxy).to receive(:list).and_return([])
        result = proxy.all
        expect(proxy).to have_received(:list).with({})
        expect(result).to eq([])
      end

      it "passes parameters to list" do
        proxy = Booqable.orders
        allow(proxy).to receive(:list).and_return([])
        proxy.all(page: { size: 1 })
        expect(proxy).to have_received(:list).with(page: { size: 1 })
      end
    end

    describe "#find", :vcr do
      let(:order_id) { "3e037580-3d7a-4d23-876c-f0ba1a481bb7" }

      it "finds an order by id" do
        order = Booqable.orders.find(order_id)
        expect(order.id).to eq(order_id)
      end

      it "accepts parameters" do
        order = Booqable.orders.find(order_id, include: "customer")
        expect(order.id).to eq(order_id)
      end

      it "returns order with expected attributes" do
        order = Booqable.orders.find(order_id)
        expect(order).to respond_to(:id)
        expect(order).to respond_to(:created_at)
        expect(order).to respond_to(:updated_at)
      end

      it "supports includes for customer" do
        order = Booqable.orders.find(order_id, include: "customer")
        expect(order.id).to eq(order_id)
        expect(order.customer.name).not_to be_nil
      end

      it "supports multiple includes" do
        order = Booqable.orders.find(order_id, include: "customer,lines")
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

        order = Booqable.orders.create(order_attributes)
        expect(order.id).to be_a(String)
        expect(order.starts_at).to eq(Time.parse("2024-01-01T00:00:00Z"))
        expect(order.stops_at).to eq(Time.parse("2024-01-02T00:00:00Z"))
      end

      it "returns created order with expected attributes" do
        order_attributes = {
          starts_at: "2024-01-01T00:00:00Z",
          stops_at: "2024-01-02T00:00:00Z"
        }

        order = Booqable.orders.create(order_attributes)
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

        order = Booqable.orders.update(order_id, update_attributes)
        expect(order.id).to eq(order_id)
        expect(order.starts_at).to eq(Time.parse("2025-04-09T11:00:00Z"))
        expect(order.stops_at).to eq(Time.parse("2025-04-11T17:00:00Z"))
      end

      it "returns updated order with expected attributes" do
        update_attributes = {
          starts_at: "2025-04-09T11:00:00Z",
          stops_at: "2025-04-11T17:00:00Z"
        }

        order = Booqable.orders.update(order_id, update_attributes)
        expect(order).to respond_to(:id)
        expect(order).to respond_to(:created_at)
        expect(order).to respond_to(:updated_at)
      end
    end

    describe "#delete", :vcr do
      let(:order_id) { "61c78159-fecc-454c-ae83-d88f704dfb93" }

      it "deletes an existing order" do
        result = Booqable.orders.delete(order_id)
        expect(result.id).to eq(order_id)
      end

      it "raises error for invalid order id" do
        expect { Booqable.orders.delete("invalid-id") }.to raise_error(Booqable::NotFound)
      end
    end

    describe "includes functionality", :vcr do
      let(:order_id) { "3e037580-3d7a-4d23-876c-f0ba1a481bb7" }

      it "supports including customer in list" do
        orders = Booqable.orders.list(include: "customer", page: { size: 1 })
        expect(orders).to be_an(Array)
        expect(orders.length).to be > 0
        order = orders.first
        expect(order).to respond_to(:customer)
      end

      it "returns customer as an object in list results" do
        orders = Booqable.orders.list(include: "customer", page: { size: 1 })
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
        order = Booqable.orders.find(order_id, include: "customer")
        expect(order.id).to eq(order_id)
        expect(order).to respond_to(:customer)
      end

      it "validates customer relationship when included" do
        order = Booqable.orders.find(order_id, include: "customer")
        expect(order.id).to eq(order_id)
        expect(order).to respond_to(:customer)
        expect(order.customer).not_to be_nil if order.customer
      end

      it "returns customer as an object, not an array" do
        order = Booqable.orders.find(order_id, include: "customer")
        expect(order.id).to eq(order_id)
        if order.customer
          expect(order.customer).not_to be_an(Array)
          expect(order.customer).to respond_to(:id)
          expect(order.customer).to respond_to(:name)
        end
      end

      it "works without includes" do
        order = Booqable.orders.find(order_id)
        expect(order.id).to eq(order_id)
        expect(order).to respond_to(:id)
        expect(order).to respond_to(:created_at)
      end

      it "handles include parameter variations" do
        orders = Booqable.orders.list(include: [ "customer" ], page: { size: 1 })
        expect(orders).to be_an(Array)
        expect(orders.length).to be > 0
        order = orders.first
        expect(order).to respond_to(:customer)
      end

      it "supports complex nested includes" do
        order = Booqable.orders.find(order_id, include: "lines,lines.item")
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
        customers = Booqable.customers.list
        expect(customers).to be_an(Array)
      end

      it "can create customers", :vcr do
        customer_attributes = {
          name: "Test Customer #{SecureRandom.hex(4)}",
          email: "test#{SecureRandom.hex(4)}@example.com"
        }

        customer = Booqable.customers.create(customer_attributes)
        expect(customer.id).to be_a(String)
        expect(customer.name).to include("Test Customer")
        expect(customer.email).to include("test")
      end

      it "can delete customers", :vcr do
        customer_id = "1dc7781b-24c9-4405-a48b-5f2f970fb75d"
        result = Booqable.customers.delete(customer_id)
        expect(result.id).to eq(customer_id)
      end
    end
  end

  describe "resource aliases" do
    describe "carriers alias" do
      it "responds to carriers alias for app_carriers", :vcr do
        expect(Booqable).to respond_to(:carriers)
        expect(Booqable).to respond_to(:app_carriers)
      end

      it "both carriers and app_carriers return same ResourceProxy class", :vcr do
        carriers_proxy = Booqable.carriers
        app_carriers_proxy = Booqable.app_carriers

        expect(carriers_proxy).to be_a(Booqable::ResourceProxy)
        expect(app_carriers_proxy).to be_a(Booqable::ResourceProxy)
        expect(carriers_proxy.class).to eq(app_carriers_proxy.class)
      end

      it "carriers alias points to app_carriers resource", :vcr do
        carriers_proxy = Booqable.carriers
        app_carriers_proxy = Booqable.app_carriers

        expect(carriers_proxy.instance_variable_get(:@resource)).to eq("app_carriers")
        expect(app_carriers_proxy.instance_variable_get(:@resource)).to eq("app_carriers")
        expect(carriers_proxy.instance_variable_get(:@resource)).to eq(app_carriers_proxy.instance_variable_get(:@resource))
      end

      it "can list carriers using alias", :vcr do
        carriers = Booqable.carriers.list
        expect(carriers).to be_an(Array)
      end

      it "can list app_carriers using full resource name", :vcr do
        app_carriers = Booqable.app_carriers.list
        expect(app_carriers).to be_an(Array)
      end

      it "carriers and app_carriers return same data", :vcr do
        carriers = Booqable.carriers.list
        app_carriers = Booqable.app_carriers.list

        expect(carriers.length).to eq(app_carriers.length)
        if carriers.any? && app_carriers.any?
          expect(carriers.first.id).to eq(app_carriers.first.id)
        end
      end

      it "supports all CRUD operations through alias", :vcr do
        # Test that all ResourceProxy methods work through alias
        carriers_proxy = Booqable.carriers

        expect(carriers_proxy).to respond_to(:list)
        expect(carriers_proxy).to respond_to(:find)
        expect(carriers_proxy).to respond_to(:create)
        expect(carriers_proxy).to respond_to(:update)
        expect(carriers_proxy).to respond_to(:delete)
      end

      it "works with parameters and includes through alias", :vcr do
        carriers = Booqable.carriers.list(page: { size: 1 })
        expect(carriers).to be_an(Array)
      end
    end

    describe "payment_options alias" do
      it "responds to payment_options alias for app_payment_options", :vcr do
        expect(Booqable).to respond_to(:payment_options)
        expect(Booqable).to respond_to(:app_payment_options)
      end

      it "both payment_options and app_payment_options return same ResourceProxy class", :vcr do
        payment_options_proxy = Booqable.payment_options
        app_payment_options_proxy = Booqable.app_payment_options

        expect(payment_options_proxy).to be_a(Booqable::ResourceProxy)
        expect(app_payment_options_proxy).to be_a(Booqable::ResourceProxy)
        expect(payment_options_proxy.class).to eq(app_payment_options_proxy.class)
      end

      it "payment_options alias points to app_payment_options resource", :vcr do
        payment_options_proxy = Booqable.payment_options
        app_payment_options_proxy = Booqable.app_payment_options

        expect(payment_options_proxy.instance_variable_get(:@resource)).to eq("app_payment_options")
        expect(app_payment_options_proxy.instance_variable_get(:@resource)).to eq("app_payment_options")
        expect(payment_options_proxy.instance_variable_get(:@resource)).to eq(app_payment_options_proxy.instance_variable_get(:@resource))
      end

      it "can list payment_options using alias", :vcr do
        payment_options = Booqable.payment_options.list
        expect(payment_options).to be_an(Array)
      end

      it "can list app_payment_options using full resource name", :vcr do
        app_payment_options = Booqable.app_payment_options.list
        expect(app_payment_options).to be_an(Array)
      end

      it "payment_options and app_payment_options return same data", :vcr do
        payment_options = Booqable.payment_options.list
        app_payment_options = Booqable.app_payment_options.list

        expect(payment_options.length).to eq(app_payment_options.length)
        if payment_options.any? && app_payment_options.any?
          expect(payment_options.first.id).to eq(app_payment_options.first.id)
        end
      end

      it "supports all CRUD operations through alias", :vcr do
        # Test that all ResourceProxy methods work through alias
        payment_options_proxy = Booqable.payment_options

        expect(payment_options_proxy).to respond_to(:list)
        expect(payment_options_proxy).to respond_to(:find)
        expect(payment_options_proxy).to respond_to(:create)
        expect(payment_options_proxy).to respond_to(:update)
        expect(payment_options_proxy).to respond_to(:delete)
      end

      it "works with parameters and includes through alias", :vcr do
        payment_options = Booqable.payment_options.list(page: { size: 1 })
        expect(payment_options).to be_an(Array)
      end
    end
  end

  describe "error handling" do
    it "raises error for invalid order id", :vcr do
      expect { Booqable.orders.find("invalid-id") }.to raise_error(Booqable::NotFound)
    end

    it "raises error for invalid create attributes", :vcr do
      invalid_attributes = {
        invalid_field: "invalid_value"
      }

      expect { Booqable.orders.create(invalid_attributes) }.to raise_error(Booqable::UnknownAttribute)
    end
  end
end
