# frozen_string_literal: true

require "json"

describe Booqable::StrictAttributes do
  let(:payload) do
    {
      "data" => {
        "id" => "order-123",
        "type" => "orders",
        "attributes" => {
          "status" => "reserved",
          "customer" => nil
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
        { "id" => "line-1", "type" => "lines", "attributes" => { "quantity" => 2 } },
        { "id" => "line-2", "type" => "lines", "attributes" => { "quantity" => 5 } }
      ]
    }
  end

  let(:resource) { Booqable::ResourceParser.parse(payload) }

  describe "reading a missing attribute" do
    it "raises Booqable::MissingAttribute" do
      expect { resource.customer_name }.to raise_error(Booqable::MissingAttribute)
    end

    it "names the missing attribute in the message" do
      expect { resource.customer_name }
        .to raise_error(Booqable::MissingAttribute, /customer_name/)
    end

    it "names the resource type in the message" do
      expect { resource.customer_name }
        .to raise_error(Booqable::MissingAttribute, /orders/)
    end

    it "lists the available attributes in the message" do
      expect { resource.customer_name }
        .to raise_error(Booqable::MissingAttribute, /status/)
    end

    it "is a NoMethodError, so generic rescues still work" do
      expect { resource.customer_name }.to raise_error(NoMethodError)
    end

    it "exposes the attribute name on the error" do
      expect { resource.customer_name }
        .to raise_error(Booqable::MissingAttribute) { |error| expect(error.name).to eq(:customer_name) }
    end

    it "raises for predicate-style reads of missing attributes" do
      expect { resource.customer_name? }
        .to raise_error(Booqable::MissingAttribute, /customer_name/)
    end

    it "raises when a missing attribute is read with arguments" do
      expect { resource.customer_name("argument") }
        .to raise_error(Booqable::MissingAttribute)
    end

    it "raises on nested resources" do
      expect { resource.lines.first.nonexistent }
        .to raise_error(Booqable::MissingAttribute, /nonexistent/)
    end

    it "falls back to a plain NoMethodError for non-attribute methods" do
      expect { resource.grab! }
        .to raise_error(NoMethodError) { |error| expect(error).not_to be_a(Booqable::MissingAttribute) }
    end

    it "keeps returning the value when method_missing is reached for a present field" do
      expect(resource.method_missing(:status)).to eq("reserved")
    end
  end

  describe "reading a present-but-null attribute" do
    it "returns nil" do
      expect(resource.customer).to be_nil
    end

    it "returns false for predicate-style reads" do
      expect(resource.customer?).to be(false)
    end
  end

  describe "Sawyer machinery that must keep working" do
    it "keeps to_h / to_attrs working" do
      expect(resource.to_h).to include(id: "order-123", status: "reserved", customer: nil)
      expect(resource.to_attrs[:lines].first).to eq(id: "line-1", type: "lines", quantity: 2)
    end

    it "keeps key? working" do
      expect(resource.key?(:customer)).to be(true)
      expect(resource.key?(:customer_name)).to be(false)
    end

    it "keeps hash-style access lenient as an explicit probe" do
      expect(resource[:status]).to eq("reserved")
      expect(resource[:customer_name]).to be_nil
    end

    it "keeps dig and fetch working" do
      expect(resource.dig(:status)).to eq("reserved")
      expect(resource.dig(:customer_name)).to be_nil
      expect { resource.fetch(:customer_name) }.to raise_error(KeyError)
    end

    it "keeps enumeration working" do
      expect(resource.map { |key, _value| key }).to include(:id, :type, :status, :customer)
    end

    it "keeps respond_to? semantics" do
      expect(resource.respond_to?(:status)).to be(true)
      expect(resource.respond_to?(:customer_name)).to be(false)
    end

    it "keeps attribute writes working, including new attributes" do
      resource.brand_new = "value"
      expect(resource.brand_new).to eq("value")
    end

    it "keeps hash-style writes working" do
      resource[:status] = "started"
      expect(resource.status).to eq("started")
    end

    it "keeps Sawyer special methods working" do
      expect(resource.fields).to include(:status)
      expect(resource.agent).to be_a(Sawyer::Agent)
      expect(resource.rels).to be_a(Sawyer::Relation::Map)
    end

    it "keeps marshaling working" do
      restored = Marshal.load(Marshal.dump(resource))
      expect(restored.status).to eq("reserved")
      expect(restored.to_h).to eq(resource.to_h)
    end
  end

  describe "scoping" do
    it "does not change behavior of Sawyer resources created by other agents" do
      other_agent = Sawyer::Agent.new("https://example.com") do |http|
        http.headers[:content_type] = "application/json"
      end
      other_resource = Sawyer::Resource.new(other_agent, { name: "octocat" })

      expect(other_resource.nonexistent).to be_nil
    end
  end

  describe "resources returned from HTTP requests" do
    it "raises MissingAttribute on resources parsed from API responses" do
      body = {
        data: {
          id: "company-1",
          type: "companies",
          attributes: { name: "Demo", default_timezone: "Europe/Amsterdam" }
        }
      }.to_json

      stub_get("companies/company-1")
        .to_return(status: 200, body: body, headers: { content_type: "application/json" })

      company = api_key_client.get("companies/company-1").data

      expect(company.default_timezone).to eq("Europe/Amsterdam")
      expect { company.time_zone }
        .to raise_error(Booqable::MissingAttribute, /time_zone/)
    end
  end
end
