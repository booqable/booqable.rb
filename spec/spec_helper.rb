# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
end

require "debug"
require "bqbl"
require "rspec"
require "vcr"
require "webmock/rspec"
WebMock.disable_net_connect!

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

VCR.configure do |c| # rubocop:disable Metrics/BlockLength
  c.configure_rspec_metadata!
  c.filter_sensitive_data("<BOOQABLE_API_KEY>") do
    test_api_key
  end
  c.filter_sensitive_data("<BOOQABLE_COMPANY>") do
    test_company
  end
  c.filter_sensitive_data("<BOOQABLE_CLIENT_ID>") do
    test_client_id
  end
  c.filter_sensitive_data("<BOOQABLE_CLIENT_SECRET>") do
    test_client_secret
  end
  c.filter_sensitive_data("<BOOQABLE_REFRESH_TOKEN>") do
    test_refresh_token
  end
  c.filter_sensitive_data("<BOOQABLE_SINGLE_USE_TOKEN>") do
    test_single_use_token
  end
  c.filter_sensitive_data("<BOOQABLE_SINGLE_USE_TOKEN_PRIVATE_KEY>") do
    test_single_use_token_private_key
  end
  c.filter_sensitive_data("<SESSION_COOKIE>") do |interaction|
    interaction.response.headers["Set-Cookie"]&.first
  end
  c.filter_sensitive_data("<SESSION_EXPIRY_TOKEN>") do |interaction|
    interaction.response.headers["Session-Expiry-Token"]&.first
  end

  c.ignore_request do |request|
    !!request.headers["X-Vcr-Test-Repo-Setup"]
  end

  record_mode =
    if ENV["CI"]
      :none
    elsif ENV["BOOQABLE_TEST_VCR_RECORD"]
      :all
    else
      :once
    end

  c.default_cassette_options = {
    serialize_with: :json,
    # preserve_exact_body_bytes: true,
    # decode_compressed_response: true,
    record: record_mode
  }
  c.cassette_library_dir = "spec/cassettes"
  c.hook_into :webmock
end

def test_company
  ENV.fetch "BOOQABLE_COMPANY", "demo"
end

def test_client_id
  ENV.fetch "BOOQABLE_CLIENT_ID", "test_client_id"
end

def test_client_secret
  ENV.fetch "BOOQABLE_CLIENT_SECRET", "test_secret"
end

def test_api_key
  ENV.fetch "BOOQABLE_API_KEY", "test_api_key"
end

def test_access_token
  ENV.fetch "BOOQABLE_ACCESS_TOKEN", "x" * 40
end

def test_refresh_token
  ENV.fetch "BOOQABLE_REFRESH_TOKEN", "x" * 40
end

def test_single_use_token
  ENV.fetch "BOOQABLE_SINGLE_USE_TOKEN", "x" * 40
end

def test_single_use_token_private_key
  ENV.fetch "BOOQABLE_SINGLE_USE_TOKEN_PRIVATE_KEY", "x" * 40
end

def test_single_use_token_algorithm
  ENV.fetch "BOOQABLE_SINGLE_USE_TOKEN_ALGORITHM", "ES256"
end

def test_single_use_token_company_id
  ENV.fetch "BOOQABLE_SINGLE_USE_TOKEN_COMPANY_ID", test_company
end

def test_single_use_token_user_id
  ENV.fetch "BOOQABLE_SINGLE_USE_TOKEN_USER_ID", "test_user_id"
end

def test_endpoint
  ENV.fetch "BOOQABLE_API_ENDPOINT", "http://demo.booqable.test"
end

def api_key_client(api_key: test_api_key, company: test_company)
  BQBL::Client.new(api_key:, company:, api_domain: "booqable.test", no_retries: true)
end

def stub_delete(url)
  stub_request(:delete, booqable_url(url))
end

def stub_get(url)
  stub_request(:get, booqable_url(url))
end

def stub_head(url)
  stub_request(:head, booqable_url(url))
end

def stub_patch(url)
  stub_request(:patch, booqable_url(url))
end

def stub_post(url)
  stub_request(:post, booqable_url(url))
end

def stub_put(url)
  stub_request(:put, booqable_url(url))
end

def booqable_defaults
  {

    api_version: "4",
    company: "demo",
    api_domain: "booqable.test"
  }
end

def booqable_url(url)
  return url if url =~ /^http/

  url = File.join(test_endpoint, "api", "4", url)
  uri = Addressable::URI.parse(url)
  uri.path.gsub!("4//", "4/")

  uri.to_s
end
