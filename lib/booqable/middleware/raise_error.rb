module Booqable
  # Faraday response middleware for the Booqable client
  module Middleware
    # Faraday middleware that raises Booqable exceptions based on HTTP status codes
    #
    # This middleware automatically converts HTTP error responses into appropriate
    # Booqable exception classes. It inspects the response status code and body to
    # determine the specific error type and raises the corresponding exception.
    #
    # @example Adding to Faraday middleware stack
    #   builder.use Booqable::Middleware::RaiseError
    #
    # @see Booqable::Error.from_response
    class RaiseError < Base
      # Handle completed HTTP responses and raise exceptions for errors
      #
      # Called by Faraday after a response is received. Inspects the response
      # and raises an appropriate Booqable exception if the status indicates an error.
      # Successful responses are allowed to pass through unchanged.
      #
      # @param response [Faraday::Response] The HTTP response object
      # @return [void]
      # @raise [Booqable::Error] Various error subclasses based on status code
      def on_complete(response)
        Booqable::Error.from_response(response)
      end
    end
  end
end
