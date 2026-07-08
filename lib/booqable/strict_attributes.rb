# frozen_string_literal: true

module Booqable
  # Sawyer::Agent used for every resource this gem creates
  #
  # Behaves exactly like Sawyer::Agent. It exists as a marker so that
  # {Booqable::StrictAttributes} can tell resources created by this gem
  # apart from resources created by other Sawyer-based gems
  # loaded in the same process.
  class SawyerAgent < Sawyer::Agent
  end

  # Strict attribute reads for resources created by this gem
  #
  # Sawyer::Resource#method_missing silently answers reads of absent
  # attributes with nil. That turns typos and renamed API fields
  # (e.g. `time_zone` vs `default_timezone`) into silent data bugs.
  # For resources created by a {Booqable::SawyerAgent}, this module raises
  # {Booqable::MissingAttribute} instead — both for plain reads
  # (`resource.foo`) and predicate reads (`resource.foo?`).
  #
  # Attributes that ARE present in the payload with a null value still
  # return nil — only reads of keys that are absent from the payload raise.
  #
  # Everything else about Sawyer::Resource is unchanged: attribute writes
  # (`resource.foo = 1`) still define new attributes, hash-style access
  # (`resource[:foo]`) stays a lenient probe returning nil for absent keys,
  # and `to_h`/`to_attrs`, `key?`, `dig`, `fetch`, enumeration, marshaling,
  # and respond_to? semantics all behave as before. Resources created by
  # other gems' Sawyer agents are unaffected.
  module StrictAttributes
    # Matches plain attribute reads (`foo`) and predicate reads (`foo?`).
    # Setters (`foo=`) stay permitted since Sawyer allows adding attributes.
    ATTRIBUTE_READ_PATTERN = /\A([a-z0-9_]+)(\?)?\z/i

    # Raise {Booqable::MissingAttribute} for reads of absent attributes
    # on strict resources; defer to Sawyer's behavior for everything else.
    def method_missing(method, *)
      attr_name = booqable_missing_attribute_read(method)
      raise Booqable::MissingAttribute.new(attr_name, self) if attr_name

      super
    end

    private

    # Returns the attribute name when +method+ is a read of an attribute
    # that is absent from the payload of a strict resource, nil otherwise
    #
    # @param method [Symbol] the method name passed to #method_missing
    # @return [Symbol, nil]
    def booqable_missing_attribute_read(method)
      # _agent/_fields are Sawyer::Resource's public attr_readers — the bare `agent`/`fields`
      # spellings are SPECIAL_METHODS resolved inside method_missing, so calling those from
      # this hook (which method_missing invokes) would recurse infinitely.
      return nil unless _agent.is_a?(Booqable::SawyerAgent)

      match = ATTRIBUTE_READ_PATTERN.match(method.to_s)
      return nil unless match

      attr_name = match[1].to_sym
      return nil if _fields.include?(attr_name)
      return nil if match[2].nil? && Sawyer::Resource::SPECIAL_METHODS.include?(match[1])

      attr_name
    end
  end
end

Sawyer::Resource.prepend(Booqable::StrictAttributes)
