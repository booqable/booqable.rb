# frozen_string_literal: true

require_relative "lib/booqable/version"

Gem::Specification.new do |spec|
  spec.name = "booqable"
  spec.version = Booqable::VERSION
  spec.authors = [ "Hrvoje Šimić" ]
  spec.email = [ "services@booqable.com" ]

  spec.summary = "Official Booqable API client for Ruby."
  spec.description = "Ruby toolkit for the Booqable API. Provides a simple interface to interact with all Booqable API endpoints including orders, customers, products, and more."
  spec.homepage = "https://github.com/booqable/booqable.rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/booqable/booqable.rb"
  spec.metadata["changelog_uri"] = "https://github.com/booqable/booqable.rb/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://developers.booqable.com/"
  spec.metadata["bug_tracker_uri"] = "https://github.com/booqable/booqable.rb/issues"

  # Specify which files should be added to the gem when it is released.
  spec.files = %w[.rspec .rubocop.yml CHANGELOG.md CODE_OF_CONDUCT.md LICENSE.txt Rakefile README.md]
  spec.files += Dir.glob("lib/**/*")
  spec.files += Dir.glob("sig/**/*")
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "faraday", "~> 2.13"
  spec.add_dependency "faraday-retry", "~> 2.3"
  spec.add_dependency "sawyer", "~> 0.9"
  spec.add_dependency "multi_json", "~> 1.15"
  spec.add_dependency "addressable", "~> 2.8"
  spec.add_dependency "oauth2", "~> 2.0"
  spec.add_dependency "jwt", "~> 3.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
