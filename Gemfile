# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in booqable.gemspec
gemspec

group :development do
  gem "rake", "~> 13.3"
  gem "rubocop", "~> 1.81"
  gem "rubocop-37signals", github: "basecamp/house-style", require: false
end

group :test do
  gem "rspec", "~> 3.13"
  gem "simplecov", "~> 0.22.0"
  gem "simplecov_json_formatter", "~> 0.1.4"
end

group :development, :test do
  gem "debug", "~> 1.11"
  gem "vcr", "~> 6.3"
  gem "webmock", "~> 3.26"
end
