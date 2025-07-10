# frozen_string_literal: true

require "json"

describe BQBL do
  it "has a version number" do
    expect(BQBL::VERSION).not_to be nil
  end

  describe "module configuration" do
    before do
      BQBL.configure do |config|
        # rubocop:disable Style/HashEachMethods
        #
        # This may look like a `.keys.each` which should be replaced with `#each_key`, but
        # this doesn't actually work, since `#keys` is just a method we've defined ourselves.
        # The class doesn't fulfill the whole `Enumerable` contract.
        BQBL::Configurable.keys.each do |key|
          # rubocop:enable Style/HashEachMethods
          config.send("#{key}=", "#{booqable_defaults.fetch(key, "Some #{key}")}")
        end
      end
    end

    after do
      BQBL.reset!
    end

    describe "method_missing delegation" do
      it "delegates to client when client responds to method" do
        # Test when client responds to the method
        allow(BQBL.client).to receive(:respond_to?).with(:some_method).and_return(true)
        allow(BQBL.client).to receive(:some_method).and_return("client response")

        expect(BQBL.some_method).to eq("client response")
      end

      it "calls super when client does not respond to method" do
        # Test the super call on line 53
        allow(BQBL.client).to receive(:respond_to?).with(:non_existent_method).and_return(false)

        expect { BQBL.non_existent_method }.to raise_error(NoMethodError)
      end

      it "passes arguments and block to client when client responds" do
        # Test argument and block passing
        allow(BQBL.client).to receive(:respond_to?).with(:method_with_args).and_return(true)
        allow(BQBL.client).to receive(:method_with_args).with("arg1", "arg2").and_return("result")

        expect(BQBL.method_with_args("arg1", "arg2")).to eq("result")
      end

      it "preserves respond_to_missing? behavior" do
        # Test the respond_to_missing? method
        allow(BQBL.client).to receive(:respond_to?).with(:client_method, false).and_return(true)
        expect(BQBL.respond_to?(:client_method)).to be true

        allow(BQBL.client).to receive(:respond_to?).with(:non_client_method, false).and_return(false)
        expect(BQBL.respond_to?(:non_client_method)).to be false
      end
    end
  end
end
