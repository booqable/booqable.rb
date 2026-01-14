# frozen_string_literal: true

module Booqable
  # Custom error class for rescuing from all Booqable errors
  #
  # Provides detailed error information from API responses including
  # status codes, headers, body content, and validation errors.
  #
  # @example Catching all Booqable errors
  #   begin
  #     Booqable.orders.find("invalid_id")
  #   rescue Booqable::Error => e
  #     puts "API Error: #{e.message}"
  #     puts "Status: #{e.response_status}"
  #     puts "Errors: #{e.errors}"
  #   end
  class Error < StandardError
    # @!attribute [r] context
    #   @return [Booqable::RateLimit, nil] Rate limit information when applicable
    attr_reader :context

    # Create and raise an appropriate error from an HTTP response
    #
    # @param response [Hash] HTTP response hash containing status, body, etc.
    # @return [nil] Returns nil if no error class is determined for the response
    # @raise [Booqable::Error] The appropriate error subclass for the response
    def self.from_response(response)
      if error = self.error_class_from_response(response)
        raise error
      end
    end

    # Returns the appropriate Booqable::Error subclass based
    # on status and response message
    #
    # @param response [Hash] HTTP response
    # @return [Booqable::Error, nil] Error instance for the response, or nil if no error class matches
    # rubocop:disable Metrics/CyclomaticComplexity
    def self.error_class_from_response(response)
      status  = response[:status].to_i
      body    = response[:body].to_s
      # headers = response[:response_headers]

      if klass =  case status
         when 400      then error_for_400(response)
         when 401      then error_for_401(response)
         when 402      then error_for_402(body)
         when 403      then Booqable::Forbidden
         when 404      then error_for_404(body)
         when 405      then Booqable::MethodNotAllowed
         when 406      then Booqable::NotAcceptable
         when 409      then Booqable::Conflict
         when 410      then Booqable::Deprecated
         when 415      then Booqable::UnsupportedMediaType
         when 422      then error_for_422(body)
         when 423      then Booqable::Locked
         when 429      then Booqable::TooManyRequests
         when 400..499 then Booqable::ClientError
         when 500      then Booqable::InternalServerError
         when 501      then Booqable::NotImplemented
         when 502      then Booqable::BadGateway
         when 503      then error_for_503(body)
         when 500..599 then Booqable::ServerError
         end
        klass.new(response)
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def build_error_context
      if RATE_LIMITED_ERRORS.include?(self.class)
        @context = Booqable::RateLimit.from_response(@response)
      end
    end

    # Initialize a new Error
    #
    # @param response [Hash, nil] HTTP response hash containing error details
    def initialize(response = nil)
      @response = response
      super(build_error_message)
      build_error_context
    end

    # Return most appropriate error for 400 HTTP status code
    # @private
    # rubocop:disable Metrics/CyclomaticComplexity
    def self.error_for_400(response)
      case response.body
      when /unwrittable_attribute/i
        Booqable::ReadOnlyAttribute
      when /unknown_attribute/i
        Booqable::UnknownAttribute
      when /extra fields should be an object/i
        Booqable::ExtraFieldsInWrongFormat
      when /fields should be an object/i
        Booqable::FieldsInWrongFormat
      when /page should be an object/i
        Booqable::PageShouldBeAnObject
      when /failed typecasting/i
        Booqable::FailedTypecasting
      when /invalid filter/i
        Booqable::InvalidFilter
      when /required filter/i
        Booqable::RequiredFilter
      when /invalid_grant/i
        error_for_invalid_grant(response)
      else
        Booqable::BadRequest
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    # Return most appropriate error for 401 HTTP status code
    # @private
    def self.error_for_401(response)
      case response.body
      when /token is invalid \(revoked\)/i
        Booqable::TokenRevoked
      else
        Booqable::Unauthorized
      end
    end

    # Return most appropriate error for 402 HTTP status code
    # @private
    # rubocop:disable Metrics/CyclomaticComplexity
    def self.error_for_402(body)
      case body
      when /feature_not_enabled/i
        Booqable::FeatureNotEnabled
      when /trial_expired/i
        Booqable::TrialExpired
      else
        Booqable::PaymentRequired
      end
    end

    # Return most appropriate error for 404 HTTP status code
    # @private
    # rubocop:disable Naming/VariableNumber
    def self.error_for_404(body)
      # rubocop:enable Naming/VariableNumber
      case body
      when /company not found/i
        Booqable::CompanyNotFound
      else
        Booqable::NotFound
      end
    end

    # Return most appropriate error for 422 HTTP status code
    # @private
    # rubocop:disable Naming/VariableNumber
    def self.error_for_422(body)
      # rubocop:enable Naming/VariableNumber
      case body
      when /is not a datetime/i
        Booqable::InvalidDateTimeFormat
      when /invalid date/i
        Booqable::InvalidDateFormat
      else
        Booqable::UnprocessableEntity
      end
    end

    # Return most appropriate error for 503 HTTP status code
    # @private
    # rubocop:disable Naming/VariableNumber
    def self.error_for_503(body)
      # rubocop:enable Naming/VariableNumber
      if body =~ /read-only/
        Booqable::ReadOnlyMode
      else
        Booqable::ServiceUnavailable
      end
    end

    # Return most appropriate error for invalid_grant OAuth error
    #
    # Determines whether the invalid_grant error is due to a revoked refresh token
    # or a different OAuth grant error by examining the grant_type parameter
    # in the request body.
    #
    # @param response [Hash] HTTP response containing the request body
    # @return [Class] RefreshTokenRevoked if grant_type is refresh_token, InvalidGrant otherwise
    # @private
    def self.error_for_invalid_grant(response)
      grant_type = CGI.parse(response.request_body).dig("grant_type", 0)

      case grant_type
      when /refresh_token/i
        Booqable::RefreshTokenRevoked
      else
        Booqable::InvalidGrant
      end
    end

    # Array of validation errors
    # @return [Array<Hash>] Error info
    def errors
      if data.is_a?(Hash)
        data[:errors] || []
      else
        []
      end
    end

    # Status code returned by the Booqable server.
    #
    # @return [Integer]
    def response_status
      @response[:status]
    end

    # Headers returned by the Booqable server.
    #
    # @return [Hash]
    def response_headers
      @response[:response_headers]
    end

    # Body returned by the Booqable server.
    #
    # @return [String]
    def response_body
      @response[:body]
    end

    private

    def data
      @data ||=
        if (body = @response[:body]) && !body.empty?
          if body.is_a?(String) &&
             @response[:response_headers] &&
             @response[:response_headers][:content_type] =~ /json/

            Sawyer::Agent.serializer.decode(body)
          else
            body
          end
        end
    end

    def response_message
      case data
      when Hash
        data[:message]
      when String
        data
      end
    end

    def response_error
      "Error: #{data[:error]}" if data.is_a?(Hash) && data[:error]
    end

    def response_error_summary
      return nil unless data.is_a?(Hash) && !Array(data[:errors]).empty?

      summary = +"\nError summary:\n"
      return summary << data[:errors] if data[:errors].is_a?(String)

      summary << data[:errors].map do |error|
        if error.is_a? Hash
          error.map { |k, v| "  #{k}: #{v}" }
        else
          "  #{error}"
        end
      end.join("\n")

      summary
    end

    def build_error_message
      return nil if @response.nil?

      message = +"#{@response[:method].to_s.upcase} "
      message << "#{redact_url(@response[:url].to_s.dup)}: "
      message << "#{@response[:status]} - "
      message << response_message.to_s unless response_message.nil?
      message << response_error.to_s unless response_error.nil?
      message << response_error_summary.to_s unless response_error_summary.nil?
      message
    end

    def redact_url(url_string)
      Client::SECRETS.each do |token|
        if url_string.include? token
          url_string.gsub!(/#{token}=\S+/, "#{token}=(redacted)")
        end
      end
      url_string
    end
  end

  # Raised on errors in the 400-499 range
  class ClientError < Error; end

  # Raised when Booqable returns a 400 HTTP status code
  class BadRequest < ClientError; end

  # Raised when Booqable returns a 400 HTTP status code
  # and body matches 'unwrittable_attribute'
  class ReadOnlyAttribute < ClientError; end

  # Raised when Booqable returns a 400 HTTP status code
  # and body matches 'unknown_attribute'
  class UnknownAttribute < ClientError; end

  # Raised when Booqable returns a 400 HTTP status code
  # and body matches 'fields should be an object'
  class FieldsInWrongFormat < ClientError; end

  # Raised when Booqable returns a 400 HTTP status code
  # and body matches 'extra fields should be an object'
  class ExtraFieldsInWrongFormat < ClientError; end

  # Raised when Booqable returns a 400 HTTP status code
  # and body matches 'page should be an object'
  class PageShouldBeAnObject < ClientError; end

  # Raised when Booqable returns a 400 HTTP status code
  # and body matches 'failed typecasting'
  class FailedTypecasting < ClientError; end

  # Raised when Booqable returns a 400 HTTP status code
  # and body matches 'invalid filter'
  class InvalidFilter < ClientError; end

  # Raised when Booqable returns a 400 HTTP status code
  # and body matches 'required filter'
  class RequiredFilter < ClientError; end

  # Raised when Booqable returns a 401 HTTP status code
  # and body matches 'token is invalid (revoked)'
  class TokenRevoked < ClientError; end

  # Raised when Booqable returns a 400 HTTP status code
  # and body matches 'invalid_grant' and
  # the grant type is refresh token (OAuth error)
  class RefreshTokenRevoked < TokenRevoked; end

  # Raised when Booqable returns a 400 HTTP status code
  # and body matches 'invalid_grant' and
  # grant type is not refresh token (OAuth error)
  class InvalidGrant < ClientError; end

  # Raised when Booqable returns a 401 HTTP status code
  class Unauthorized < ClientError; end

  # Raised when Booqable returns a 402 HTTP status code
  class PaymentRequired < ClientError; end

  # Raised when Booqable returns a 402 HTTP status code
  # and body matches 'feature_not_enabled'
  class FeatureNotEnabled < PaymentRequired; end

  # Raised when Booqable returns a 402 HTTP status code
  # and body matches 'trial_expired'
  class TrialExpired < PaymentRequired; end

  # Raised when Booqable returns a 403 HTTP status code
  class Forbidden < ClientError; end

  # Raised when Booqable returns a 403 HTTP status code
  # and body matches 'rate limit exceeded'
  class TooManyRequests < Forbidden; end

  # Raised when Booqable returns a 404 HTTP status code
  class NotFound < ClientError; end

  # Raised when Booqable returns a 404 HTTP status code
  # and body matches 'company not found'
  class CompanyNotFound < NotFound; end

  # Raised when Booqable returns a 405 HTTP status code
  class MethodNotAllowed < ClientError; end

  # Raised when Booqable returns a 406 HTTP status code
  class NotAcceptable < ClientError; end

  # Raised when Booqable returns a 409 HTTP status code
  class Conflict < ClientError; end

  # Raised when Booqable returns a 410 HTTP status code
  class Deprecated < ClientError; end

  # Raised when Booqable returns a 414 HTTP status code
  class UnsupportedMediaType < ClientError; end

  # Raised when Booqable returns a 423 HTTP status code
  class Locked < ClientError; end

  # Raised when Booqable returns a 422 HTTP status code
  class UnprocessableEntity < ClientError; end

  # Raised when Booqable returns a 422 HTTP status code and body matches 'is not a datetime'.
  class InvalidDateTimeFormat < UnprocessableEntity; end

  # Raised when Booqable returns a 422 HTTP status code and body matches 'invalid date'.
  class InvalidDateFormat < UnprocessableEntity; end

  # Raised on errors in the 500-599 range
  class ServerError < Error; end

  # Raised when Booqable returns a 500 HTTP status code
  class InternalServerError < ServerError; end

  # Raised when Booqable returns a 501 HTTP status code
  class NotImplemented < ServerError; end

  # Raised when Booqable returns a 502 HTTP status code
  class BadGateway < ServerError; end

  # Raised when Booqable returns a 503 HTTP status code
  class ServiceUnavailable < ServerError; end

  # Raised when Booqable returns a 503 HTTP status code
  # and body matches 'read-only'
  class ReadOnlyMode < ServerError; end

  # Raised when Booqable configuration is invalid
  class ConfigArgumentError < ArgumentError; end

  # Raised when a company slug is not set in Booqable configuration
  class CompanyRequired < ArgumentError
    def initialize
      super("Company ID is required. Please set `company_id` in Booqable configuration.")
    end
  end

  # Raised when a company ID is not set in Booqable configuration
  # and single-use token auth method is used.
  class SingleUseTokenCompanyIdRequired < ArgumentError
    def initialize
      super("Single use token company ID is required. Please set `single_use_token_company_id` in Booqable configuration.")
    end
  end

  # Raised when a user ID is not set in Booqable configuration
  # and single-use token auth method is used.
  class SingleUseTokenUserIdRequired < ArgumentError
    def initialize
      super("Single use token user ID is required. Please set `single_use_token_company_id` in Booqable configuration.")
    end
  end

  # Raised when a single-use token algorithm is not set in Booqable configuration
  # and single-use token auth method is used.
  class SingleUseTokenAlgorithmRequired < ConfigArgumentError
    def initialize
      super("Single use token algorithm is required. Please set `single_use_token_algorithm` in Booqable configuration.")
    end
  end

  # Raised when a private key or secret is not set in Booqable configuration
  class PrivateKeyOrSecretRequired < ConfigArgumentError
    def initialize
      super("Private key or secret is required. Please set `single_use_token_private_key` or `single_use_token_secret` in Booqable configuration.")
    end
  end

  class UnsupportedAPIVersion < ConfigArgumentError
    def initialize
      super("Unsupported API version configured. Only version '4' is supported.")
    end
  end

  # Raised when a required authentication parameter is missing
  class RequiredAuthParamMissing < ArgumentError; end

  RATE_LIMITED_ERRORS = [ Booqable::TooManyRequests ].freeze
end
