# frozen_string_literal: true

require "json"

describe Booqable::ResourceParser do
  describe ".parse" do
    context "with valid JSON string payload" do
      let(:payload) do
        {
          "data" => {
            "id" => "abc-123",
            "type" => "customers",
            "attributes" => {
              "name" => "John Doe",
              "email" => "john@example.com",
              "created_at" => "2024-01-15T10:30:00Z"
            }
          }
        }.to_json
      end

      it "returns a Sawyer::Resource" do
        result = described_class.parse(payload)
        expect(result).to be_a(Sawyer::Resource)
      end

      it "provides dot-notation access to attributes" do
        result = described_class.parse(payload)
        expect(result.id).to eq("abc-123")
        expect(result.name).to eq("John Doe")
        expect(result.email).to eq("john@example.com")
      end

      it "auto-parses time fields" do
        result = described_class.parse(payload)
        expect(result.created_at).to be_a(Time)
        expect(result.created_at.year).to eq(2024)
        expect(result.created_at.month).to eq(1)
        expect(result.created_at.day).to eq(15)
      end
    end

    context "with Hash payload" do
      let(:payload) do
        {
          "data" => {
            "id" => "def-456",
            "type" => "orders",
            "attributes" => {
              "status" => "reserved",
              "number" => 1001
            }
          }
        }
      end

      it "returns a Sawyer::Resource" do
        result = described_class.parse(payload)
        expect(result).to be_a(Sawyer::Resource)
      end

      it "provides dot-notation access to attributes" do
        result = described_class.parse(payload)
        expect(result.id).to eq("def-456")
        expect(result.status).to eq("reserved")
        expect(result.number).to eq(1001)
      end
    end

    context "with nested relationships" do
      let(:payload) do
        {
          "data" => {
            "id" => "order-123",
            "type" => "orders",
            "attributes" => {
              "status" => "reserved"
            },
            "relationships" => {
              "customer" => {
                "data" => { "id" => "customer-456", "type" => "customers" }
              }
            }
          },
          "included" => [
            {
              "id" => "customer-456",
              "type" => "customers",
              "attributes" => {
                "name" => "Jane Smith",
                "email" => "jane@example.com"
              }
            }
          ]
        }
      end

      it "populates relationships from included resources" do
        result = described_class.parse(payload)
        expect(result.customer).to be_a(Sawyer::Resource)
        expect(result.customer.id).to eq("customer-456")
        expect(result.customer.name).to eq("Jane Smith")
        expect(result.customer.email).to eq("jane@example.com")
      end
    end

    context "with to-many relationships" do
      let(:payload) do
        {
          "data" => {
            "id" => "order-123",
            "type" => "orders",
            "attributes" => {
              "status" => "reserved"
            },
            "relationships" => {
              "lines" => {
                "data" => [
                  { "id" => "line-1", "type" => "lines" },
                  { "id" => "line-2", "type" => "lines" }
                ]
              }
            }
          },
          "included" => [
            {
              "id" => "line-1",
              "type" => "lines",
              "attributes" => { "quantity" => 2 }
            },
            {
              "id" => "line-2",
              "type" => "lines",
              "attributes" => { "quantity" => 5 }
            }
          ]
        }
      end

      it "populates to-many relationships as an array" do
        result = described_class.parse(payload)
        expect(result.lines).to be_an(Array)
        expect(result.lines.length).to eq(2)
        expect(result.lines[0].id).to eq("line-1")
        expect(result.lines[0].quantity).to eq(2)
        expect(result.lines[1].id).to eq("line-2")
        expect(result.lines[1].quantity).to eq(5)
      end
    end

    context "with deeply nested relationships" do
      let(:payload) do
        {
          "data" => {
            "id" => "order-123",
            "type" => "orders",
            "attributes" => { "status" => "reserved" },
            "relationships" => {
              "customer" => {
                "data" => { "id" => "customer-456", "type" => "customers" }
              }
            }
          },
          "included" => [
            {
              "id" => "customer-456",
              "type" => "customers",
              "attributes" => { "name" => "Jane Smith" },
              "relationships" => {
                "default_address" => {
                  "data" => { "id" => "address-789", "type" => "addresses" }
                }
              }
            },
            {
              "id" => "address-789",
              "type" => "addresses",
              "attributes" => {
                "city" => "Amsterdam",
                "country" => "Netherlands"
              }
            }
          ]
        }
      end

      it "populates nested relationships recursively" do
        result = described_class.parse(payload)
        expect(result.customer.name).to eq("Jane Smith")
        expect(result.customer.default_address.city).to eq("Amsterdam")
        expect(result.customer.default_address.country).to eq("Netherlands")
      end
    end

    context "with various time field formats" do
      let(:payload) do
        {
          "data" => {
            "id" => "123",
            "type" => "events",
            "attributes" => {
              "created_at" => "2024-01-15T10:30:00Z",
              "updated_at" => "2024-02-20T15:45:00Z",
              "published_on" => "2024-03-01T00:00:00Z",
              "start_date" => "2024-04-15T09:00:00Z",
              "name" => "Not a time field"
            }
          }
        }
      end

      it "parses _at suffixed fields as Time" do
        result = described_class.parse(payload)
        expect(result.created_at).to be_a(Time)
        expect(result.updated_at).to be_a(Time)
      end

      it "parses _on suffixed fields as Time" do
        result = described_class.parse(payload)
        expect(result.published_on).to be_a(Time)
      end

      it "parses _date suffixed fields as Time" do
        result = described_class.parse(payload)
        expect(result.start_date).to be_a(Time)
      end

      it "does not parse non-time fields" do
        result = described_class.parse(payload)
        expect(result.name).to eq("Not a time field")
        expect(result.name).to be_a(String)
      end
    end

    context "with nil payload" do
      it "returns nil" do
        result = described_class.parse(nil)
        expect(result).to be_nil
      end
    end

    context "with empty string payload" do
      it "returns nil" do
        result = described_class.parse("")
        expect(result).to be_nil
      end
    end

    context "with whitespace-only payload" do
      it "returns nil" do
        result = described_class.parse("   ")
        expect(result).to be_nil
      end
    end

    context "with payload missing data key" do
      let(:payload) do
        { "meta" => { "total" => 0 } }
      end

      it "returns nil" do
        result = described_class.parse(payload)
        expect(result).to be_nil
      end
    end

    context "with empty hash payload" do
      it "returns nil" do
        result = described_class.parse({})
        expect(result).to be_nil
      end
    end
  end
end
