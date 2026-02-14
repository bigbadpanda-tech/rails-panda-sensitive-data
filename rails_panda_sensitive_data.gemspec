$LOAD_PATH.push File.expand_path("lib", __dir__)

require "rails_panda_sensitive_data/version"

Gem::Specification.new do |spec|
  spec.name = "rails-panda-sensitive-data"
  spec.version = RailsPanda::SensitiveData::VERSION
  spec.authors = ["João Saraiva"]
  spec.email = ["panda@bigbadpanda.com"]

  spec.summary = "Code that Rails applications use for dealing with sensitive data (e.g., GDPR)."
  spec.description = "Code that Rails applications use for dealing with sensitive data (e.g., GDPR)."
  spec.homepage = "https://github.com/bigbadpanda-tech/rails-panda-sensitive-data"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/develop/CHANGELOG.md"

  spec.files = Dir[
    "lib/**/*",
    "rails_panda_sensitive_data.gemspec",
    "Gemfile",
    # "Rakefile",
    "LICENSE",
    "CHANGELOG.md",
    "README.md"
  ]

  spec.add_dependency "rails", ">= 7.0.0"

  # spec.add_development_dependency "combustion"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-rails"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "rubocop-rails"
  spec.add_development_dependency "rubocop-rspec"
  spec.add_development_dependency "rubocop-rspec_rails"
  spec.add_development_dependency "rubocop-rake"
  spec.add_development_dependency "rubocop-performance"
  spec.add_development_dependency "standard"
  spec.add_development_dependency "standard-rails"
  spec.add_development_dependency "sqlite3"
end
