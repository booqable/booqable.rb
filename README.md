# BQBL

Ruby toolkit for the [Booqable API](https://developers.booqable.com/).

[Booqable](https://booqable.com) is a rental management platform that helps businesses manage their rental inventory, customers, and orders. This gem provides a Ruby interface to interact with all Booqable API endpoints.

## Table of Contents
- [Installation](#installation)
- [Making requests](#making-requests)
- [Authentication](#authentication)
- [Configuration](#configuration)
- [Pagination](#pagination)
- [Rate limiting](#rate-limiting)
- [Resources](#resources)
- [Advanced usage](#advanced-usage)
- [Development](#development)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bqbl'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install bqbl
```

## Making requests

API methods are available as module methods (consuming module-level configuration) or as client instance methods.

```ruby
# Provide authentication credentials
BQBL.configure do |c|
  c.api_key = 'your_api_key_here'
  c.company = 'your_company_subdomain'
end

# Fetch orders
orders = BQBL.orders.list
```

or

```ruby
# Create a client instance
client = BQBL::Client.new(
  api_key: 'your_api_key_here',
  company: 'your_company_subdomain'
)

# Fetch orders
orders = client.orders.list
```

## Authentication

BQBL supports several authentication methods to suit different use cases:

### API Key Authentication (Recommended)

The simplest way to authenticate is with an API key:

```ruby
BQBL.configure do |c|
  c.api_key = 'your_api_key_here'
  c.company = 'your_company_subdomain'
end
```

Generate your API key from your Booqable account settings. [Learn more about API keys](https://developers.booqable.com/#authentication-access-token).

### OAuth2 Authentication

For applications that need to act on behalf of multiple users:

```ruby
client = BQBL::Client.new(
  client_id: 'your_oauth_client_id',
  client_secret: 'your_oauth_client_secret',
  company: 'your_company_subdomain',
  read_token: -> { 
    # Return stored token hash
    JSON.parse(File.read('token.json'))
  },
  write_token: ->(token) { 
    # Store token hash
    File.write('token.json', token.to_json)
  }
)

# Complete OAuth flow
client.authenticate_with_code(params[:code])
```

### Single-Use Token Authentication

For server-to-server communication requiring enhanced security:

```ruby
client = BQBL::Client.new(
  single_use_token: 'your_token_id',
  single_use_token_algorithm: 'HS256',
  single_use_token_secret: 'your_signing_secret',
  single_use_token_company_id: 'company_uuid',
  single_use_token_user_id: 'user_uuid',
  company: 'your_company_subdomain'
)
```

Supports HS256 (HMAC), RS256 (RSA), and ES256 (ECDSA) algorithms. [Learn more about request signing](https://developers.booqable.com/#authentication-request-signing).

### Environment Variables

All authentication options can be configured via environment variables:

```bash
export BOOQABLE_API_KEY="your_api_key_here"
export BOOQABLE_COMPANY="your_company_subdomain"
export BOOQABLE_CLIENT_ID="your_oauth_client_id"
export BOOQABLE_CLIENT_SECRET="your_oauth_client_secret"
```

## Configuration

BQBL is highly configurable to suit different environments and use cases:

```ruby
BQBL.configure do |c|
  c.api_key = 'your_api_key_here'
  c.company = 'your_company_subdomain'
  c.api_domain = 'booqable.com'        # Default
  c.api_version = 4                    # Default
  c.per_page = 25                      # Default pagination size
  c.auto_paginate = true               # Auto-fetch all pages
end
```

### Per-client configuration

```ruby
client = BQBL::Client.new(
  api_key: 'your_api_key_here',
  company: 'your_company_subdomain',
  per_page: 50,
  auto_paginate: false
)
```

## Pagination

The Booqable API uses cursor-based pagination. BQBL provides several ways to handle paginated responses:

### Manual pagination

```ruby
# Fetch first page
orders = BQBL.orders.list(page: { size: 25, number: 1 })

# Fetch next page
next_orders = BQBL.orders.list(page: { size: 25, number: 2 })
```

### Auto-pagination

```ruby
# Configure auto-pagination
BQBL.auto_paginate = true

# This will automatically fetch ALL orders across all pages
all_orders = BQBL.orders.list
```

## Rate limiting

BQBL automatically handles rate limiting and provides access to rate limit information:

```ruby
orders = BQBL.orders.list

# Check rate limit status
rate_limit = BQBL.rate_limit
puts "Remaining requests: #{rate_limit.remaining}"
puts "Reset time: #{rate_limit.reset_at}"
puts "Limit: #{rate_limit.limit}"
```

### Automatic retries

BQBL includes automatic retry logic so every request will be retried two times
by default if it fails due to a server error.

To disable automatic retries, you can configure it globally:

```ruby
BQBL.configure do |c|
  c.no_retries = true # Disable automatic retries
end
```

## Resources

BQBL provides access to all Booqable API resources through a consistent interface:

### Orders

```ruby
# List orders with filtering and includes
orders = BQBL.orders.list(
  include: 'customer,items',
  filter: { status: 'reserved' },
  sort: '-created_at'
)

# Find specific order
order = BQBL.orders.find('order_id', include: 'customer,items')
order.items.count
order.customer.name

# Create order
new_order = BQBL.orders.create(
  starts_at: '2024-01-01T00:00:00Z',
  stops_at: '2024-01-02T00:00:00Z',
  status: 'draft'
)
new_order.status  # => 'draft'

# Update order
updated_order = BQBL.orders.update('order_id', status: 'reserved')
updated_order.status  # => 'reserved'
```

### Customers

```ruby
# List customers
customers = BQBL.customers.list(
  filter: { name: 'John' },
  sort: 'created_at'
)

# Create customer
customer = BQBL.customers.create(
  name: 'John Doe',
  email: 'john@example.com'
)

# Update customer
BQBL.customers.update('customer_id', name: 'Jane Doe')
```

### Products

```ruby
# List products with inventory information
products = BQBL.products.list(
  include: 'inventory_levels',
  filter: { type: 'trackable' }
)

# Find product
product = BQBL.products.find('product_id', include: 'properties')

# Create product
product = BQBL.products.create(
  name: 'Camera',
  type: 'trackable',
  base_price_in_cents: 50000
)
```

### Available resources

BQBL provides access to all Booqable API resources:

**Core Resources:**
- `orders`, `customers`, `products`, `items`
- `employees`, `companies`, `locations`
- `payments`, `invoices`, `documents`

**Inventory Management:**
- `inventory_levels`, `stock_items`, `stock_adjustments`
- `transfers`, `plannings`, `clusters`

**Configuration:**
- `settings`, `properties`, `tax_rates`
- `payment_methods`, `email_templates`

**And many more...** See the [full resource list](lib/bqbl/resources.json) for all available endpoints.

## Advanced usage

### Custom middleware

BQBL uses Faraday for HTTP requests. You can customize the middleware stack:

```ruby
BQBL.configure do |c|
  c.middleware = Faraday::RackBuilder.new do |builder|
    builder.use MyCustomMiddleware
    builder.use BQBL::Middleware::RaiseError
    builder.adapter Faraday.default_adapter
  end
end
```

### Connection options

```ruby
BQBL.configure do |c|
  c.connection_options = {
    headers: { 'X-Custom-Header' => 'value' },
    ssl: { verify: false },
    timeout: 30
  }
end
```

### Proxy support

```ruby
BQBL.configure do |c|
  c.proxy = 'http://proxy.example.com:8080'
end
```

### Custom serialization

```ruby
# Access raw response data
response = BQBL.orders.list
puts response.class  # => Sawyer::Resource

# Get response metadata
puts BQBL.last_response.status
puts BQBL.last_response.headers
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Running tests

```bash
# Run all tests
bundle exec rake spec

# Run specific test file
bundle exec rspec spec/bqbl/client_spec.rb
```

### Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/booqable/bqbl.rb. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/booqable/bqbl.rb/blob/master/CODE_OF_CONDUCT.md).

## Versioning

This library aims to support and is [tested against](https://github.com/booqable/bqbl.rb/actions) the following Ruby versions:

- Ruby 3.0
- Ruby 3.1
- Ruby 3.2
- Ruby 3.3
- Ruby 3.4

If something doesn't work on one of these versions, it's a bug.

This library may inadvertently work (or seem to work) on other Ruby versions, however support will only be provided for the versions listed above.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the BQBL project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/booqable/bqbl.rb/blob/master/CODE_OF_CONDUCT.md).

---

**Questions?** Check out the [Booqable API documentation](https://developers.booqable.com/) or [open an issue](https://github.com/booqable/bqbl.rb/issues/new).
