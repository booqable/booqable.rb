module Booqable
  # JSON API serializer with support for multiple JSON backends
  #
  # Handles encoding and decoding of JSON API responses with automatic
  # relationship population and attribute transformation. Supports multiple
  # JSON libraries including the standard JSON gem, Yajl, and MultiJson.
  #
  # See: https://github.com/lostisland/sawyer/blob/142c8fd9ee82bc01dd71e1929be0e4fd975fd9ed/lib/sawyer/serializer.rb
  #
  # @example Basic usage
  #   serializer = Booqable::JsonApiSerializer.any_json
  #   data = { "name" => "Order", "created_at" => Time.now }
  #   encoded = serializer.encode(data)
  #   decoded = serializer.decode(encoded)
  class JsonApiSerializer
    # Get the first available JSON serializer
    #
    # Tries different JSON libraries in order of preference and returns
    # the first one that's available.
    #
    # @return [Booqable::JsonApiSerializer] A serializer instance
    # @raise [RuntimeError] If no JSON library is available
    def self.any_json
      yajl || multi_json || json || begin
        raise RuntimeError, "Sawyer requires a JSON gem: yajl, multi_json, or json"
      end
    end

    # Create a serializer using the Yajl JSON library
    #
    # @return [Booqable::JsonApiSerializer, nil] Serializer instance or nil if Yajl unavailable
    def self.yajl
      require "yajl"
      new(Yajl)
    rescue LoadError
    end

    # Create a serializer using the standard JSON library
    #
    # @return [Booqable::JsonApiSerializer, nil] Serializer instance or nil if JSON unavailable
    def self.json
      require "json"
      new(JSON)
    rescue LoadError
    end

    # Create a serializer using the MultiJson library
    #
    # @return [Booqable::JsonApiSerializer, nil] Serializer instance or nil if MultiJson unavailable
    def self.multi_json
      require "multi_json"
      new(MultiJson)
    rescue LoadError
    end

    # Create a serializer using the MessagePack library
    #
    # @return [Booqable::JsonApiSerializer, nil] Serializer instance or nil if MessagePack unavailable
    def self.message_pack
      require "msgpack"
      new(MessagePack, :pack, :unpack)
    rescue LoadError
    end

    # Initialize a new serializer
    #
    # Wraps a serialization format for JSON API processing. Nested objects are
    # prepared for serialization (such as changing Times to ISO 8601 Strings).
    # Any serialization format that responds to #dump and #load will work.
    #
    # @param format [Object] The JSON library to use (e.g., JSON, Yajl)
    # @param dump_method_name [Symbol, nil] Method name for encoding (default: :dump)
    # @param load_method_name [Symbol, nil] Method name for decoding (default: :load)
    def initialize(format, dump_method_name = nil, load_method_name = nil)
      @format = format
      @dump = @format.method(dump_method_name || :dump)
      @load = @format.method(load_method_name || :load)
    end

    # Encode an object to JSON
    #
    # Encodes an Object (usually a Hash or Array of Hashes) with special
    # handling for dates, times, and nested structures.
    #
    # @param data [Object] Object to be encoded
    # @return [String] JSON-encoded string
    def encode(data)
      @dump.call(encode_object(data))
    end

    alias dump encode

    # Decode JSON data to Ruby objects
    #
    # Decodes a JSON string into Ruby objects (usually a Hash or Array of
    # Hashes) with JSON API relationship population and attribute transformation.
    #
    # @param data [String, nil] JSON string to be decoded
    # @return [Object, nil] Decoded Ruby object, or nil for empty/nil input
    def decode(data)
      return nil if data.nil? || data.strip.empty?
      decoded = decode_object(@load.call(data))
    end

    alias load decode

    private

    def encode_object(data)
      case data
      when Hash then encode_hash(data)
      when Array then data.map { |o| encode_object(o) }
      else data
      end
    end

    def encode_hash(hash)
      hash.keys.each do |key|
        case value = hash[key]
        when Date then hash[key] = value.to_time.utc.xmlschema
        when Time then hash[key] = value.utc.xmlschema
        when Hash then hash[key] = encode_hash(value)
        end
      end
      hash
    end

    def decode_object(data)
      case data
      when Hash then decode_hash(data)
      when Array then data.map { |o| decode_object(o) }
      else data
      end
    end

    def decode_hash(hash)
      populate_relationships(hash["data"], hash["included"]) if hash.key?("included")

      transform_hash_keys(hash)

      hash.keys.each do |key|
        hash[key.to_sym] = decode_hash_value(key, hash.delete(key))
      end

      hash
    end

    def transform_hash_keys(hash)
      hash["_includes"] = hash.delete("included") if hash.key?("included")

      case hash
      when Array
        hash = hash.map { |item| transform_hash(item, hash) }
      when Hash
        hash = transform_hash(hash)
      else hash
      end
    end

    def transform_hash(hash, parent = nil)
      transform_attributes(hash)
      transform_relationships(hash, parent)
    end

    def transform_attributes(hash)
      if hash.key?("attributes")
        attributes = hash.delete("attributes")
        hash.merge!(attributes)
      end
    end

    def transform_relationships(hash, parent)
      return unless hash.key?("relationships")

      hash["_relationships"] = hash.delete("relationships")
      hash["_relationships"].each do |key, value|
        next unless value.is_a?(Hash) && value.key?("data")

        relationship_data = value["data"]

        # Handle single relationship (to-one)
        if relationship_data.is_a?(Hash)
          hash[key] = relationship_data
        # Handle multiple relationships (to-many)
        elsif relationship_data.is_a?(Array)
          hash[key] = relationship_data
        end
      end

      hash.delete("_relationships")
    end

    def populate_relationships(obj, includes = [])
      case obj
      when Array
        obj.each do |item|
          populate_relationships(item, includes)
        end
      when Hash
        if obj.key?("relationships")
          obj["relationships"].each do |key, value|
            next unless value.is_a?(Hash) && value.key?("data")

            relationship_data = value["data"]

            # Handle single relationship (to-one)
            if relationship_data.is_a?(Hash)
              if relationship_data.key?("id") && relationship_data.key?("type")
                found_include = includes.find { |inc| inc["id"] == relationship_data["id"] && inc["type"] == relationship_data["type"] }
                if found_include
                  value["data"] = found_include
                  # Recursively populate nested relationships
                  populate_relationships(found_include, includes)
                else
                  value["data"] = relationship_data
                end
              end
            # Handle multiple relationships (to-many)
            elsif relationship_data.is_a?(Array)
              value["data"] = relationship_data.map do |relationship|
                if relationship.is_a?(Hash) && relationship.key?("id") && relationship.key?("type")
                  found_include = includes.find { |inc| inc["id"] == relationship["id"] && inc["type"] == relationship["type"] }
                  if found_include
                    # Recursively populate nested relationships
                    populate_relationships(found_include, includes)
                    found_include
                  else
                    relationship
                  end
                else
                  relationship
                end
              end
            end
          end
        end
      end
    end

    def decode_hash_value(key, value)
      if time_field?(key, value)
        if value.is_a?(String)
          begin
            Time.parse(value)
          rescue ArgumentError
            value
          end
        elsif value.is_a?(Integer) || value.is_a?(Float)
          Time.at(value)
        else
          value
        end
      elsif value.is_a?(Hash)
        decode_hash(value)
      elsif value.is_a?(Array)
        value.map { |o| decode_hash_value(key, o) }
      else
        value
      end
    end

    def time_field?(key, value)
      value && (key =~ /_(at|on)\z/ || key =~ /(\A|_)date\z/)
    end
  end
end
