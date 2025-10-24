# Booqable.rb

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
gem 'booqable'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install booqable
```

## Making requests

API methods are available as module methods (consuming module-level configuration) or as client instance methods.

```ruby
# Provide authentication credentials
Booqable.configure do |c|
  c.api_key = 'your_api_key_here'
  c.company_id = 'your_company_id'
end

# Fetch orders
orders = Booqable.orders.list
```

or

```ruby
# Create a client instance
client = Booqable::Client.new(
  api_key: 'your_api_key_here',
  company_id: 'your_company_id'
)

# Fetch orders
orders = client.orders.list
```

## Authentication

Booqable supports several authentication methods to suit different use cases:

### API Key Authentication (Recommended)

The simplest way to authenticate is with an API key:

```ruby
Booqable.configure do |c|
  c.api_key = 'your_api_key_here'
  c.company_id = 'your_company_id'
end
```

Generate your API key from your Booqable account settings. [Learn more about API keys](https://developers.booqable.com/#authentication-access-token).

### OAuth2 Authentication

For applications that need to act on behalf of multiple users:

```ruby
client = Booqable::Client.new(
  client_id: 'your_oauth_client_id',
  client_secret: 'your_oauth_client_secret',
  company_id: 'your_company_id',
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
client = Booqable::Client.new(
  single_use_token: 'your_token_id',
  single_use_token_algorithm: 'HS256',
  single_use_token_secret: 'your_signing_secret',
  single_use_token_company_id: 'company_uuid',
  single_use_token_user_id: 'user_uuid',
  company_id: 'your_company_id'
)
```

Supports HS256 (HMAC), RS256 (RSA), and ES256 (ECDSA) algorithms. [Learn more about request signing](https://developers.booqable.com/#authentication-request-signing).

### Environment Variables

All authentication options can be configured via environment variables:

```bash
export BOOQABLE_API_KEY="your_api_key_here"
export BOOQABLE_COMPANY="your_company_id"
export BOOQABLE_CLIENT_ID="your_oauth_client_id"
export BOOQABLE_CLIENT_SECRET="your_oauth_client_secret"
```

## Configuration

Booqable is highly configurable to suit different environments and use cases:

```ruby
Booqable.configure do |c|
  c.api_key = 'your_api_key_here'
  c.company_id = 'your_company_id'
  c.api_domain = 'booqable.com'        # Default
  c.api_version = 4                    # Default
  c.per_page = 25                      # Default pagination size
  c.auto_paginate = true               # Auto-fetch all pages
end
```

### Per-client configuration

```ruby
client = Booqable::Client.new(
  api_key: 'your_api_key_here',
  company_id: 'your_company_id',
  per_page: 50,
  auto_paginate: false
)
```

## Pagination

Booqable provides several ways to handle paginated responses:

### Manual pagination

```ruby
# Fetch first page
orders = Booqable.orders.list(page: { size: 25, number: 1 })

# Fetch next page
next_orders = Booqable.orders.list(page: { size: 25, number: 2 })
```

### Auto-pagination

```ruby
# Configure auto-pagination
Booqable.auto_paginate = true

# This will automatically fetch ALL orders across all pages
all_orders = Booqable.orders.list
```

## Rate limiting

Booqable automatically handles rate limiting and provides access to rate limit information:

```ruby
orders = Booqable.orders.list

# Check rate limit status
rate_limit = Booqable.rate_limit
puts "Remaining requests: #{rate_limit.remaining}"
puts "Reset time: #{rate_limit.reset_at}"
puts "Limit: #{rate_limit.limit}"
```

### Automatic retries

Booqable includes automatic retry logic so every request will be retried two times
by default if it fails due to a server error.

To disable automatic retries, you can configure it globally:

```ruby
Booqable.configure do |c|
  c.no_retries = true # Disable automatic retries
end
```

## Resources

Booqable provides access to all Booqable API resources through a consistent interface:

### Orders

```ruby
# List orders with filtering and includes
orders = Booqable.orders.list(
  include: 'customer,items',
  filter: { status: 'reserved' },
  sort: '-created_at'
)

# Find specific order
order = Booqable.orders.find('order_id', include: 'customer,items')
order.items.count
order.customer.name

# Create order
new_order = Booqable.orders.create(
  starts_at: '2024-01-01T00:00:00Z',
  stops_at: '2024-01-02T00:00:00Z',
  status: 'draft'
)
new_order.status  # => 'draft'

# Update order
updated_order = Booqable.orders.update('order_id', status: 'reserved')
updated_order.status  # => 'reserved'

# Delete order
deleted_order = Booqable.orders.delete('order_id')
deleted_order.id  # => 'order_id'
```

### Customers

```ruby
# List customers
customers = Booqable.customers.list(
  filter: { name: 'John' },
  sort: 'created_at'
)

# Create customer
customer = Booqable.customers.create(
  name: 'John Doe',
  email: 'john@example.com'
)

# Update customer
Booqable.customers.update('customer_id', name: 'Jane Doe')

# Delete customer
deleted_customer = Booqable.customers.delete('customer_id')
deleted_customer.id  # => 'customer_id'
```

### Products

```ruby
# List products with inventory information
products = Booqable.products.list(
  include: 'inventory_levels',
  filter: { type: 'trackable' }
)

# Find product
product = Booqable.products.find('product_id', include: 'properties')

# Create product
product = Booqable.products.create(
  name: 'Camera',
  type: 'trackable',
  base_price_in_cents: 50000
)

# Delete product
deleted_product = Booqable.products.delete('product_id')
deleted_product.id  # => 'product_id'
```

### Available resources

Booqable provides access to all Booqable API resources:

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

**And many more...** See the [full resource list](lib/booqable/resources.json) for all available endpoints.

## Advanced usage

### Custom middleware

Booqable uses Faraday for HTTP requests. You can customize the middleware stack:

```ruby
Booqable.configure do |c|
  c.middleware = Faraday::RackBuilder.new do |builder|
    builder.use MyCustomMiddleware
    builder.use Booqable::Middleware::RaiseError
    builder.adapter Faraday.default_adapter
  end
end
```

### Connection options

```ruby
Booqable.configure do |c|
  c.connection_options = {
    headers: { 'X-Custom-Header' => 'value' },
    ssl: { verify: false },
    timeout: 30
  }
end
```

### Proxy support

```ruby
Booqable.configure do |c|
  c.proxy = 'http://proxy.example.com:8080'
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Running tests

```bash
# Run all tests
bundle exec rake spec

# Run specific test file
bundle exec rspec spec/booqable/client_spec.rb
```

### Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/booqable/booqable.rb. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/booqable/booqable.rb/blob/master/CODE_OF_CONDUCT.md).

## Versioning

This library aims to support and is [tested against](https://github.com/booqable/booqable.rb/actions) the following Ruby versions:

- Ruby 3.2
- Ruby 3.3
- Ruby 3.4

If something doesn't work on one of these versions, it's a bug.

This library may inadvertently work (or seem to work) on other Ruby versions, however support will only be provided for the versions listed above.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Booqable project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/booqable/booqable.rb/blob/master/CODE_OF_CONDUCT.md).

---

**Questions?** Check out the [Booqable API documentation](https://developers.booqable.com/) or [open an issue](https://github.com/booqable/booqable.rb/issues/new).
