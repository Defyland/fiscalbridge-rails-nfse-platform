source "https://rubygems.org"

ruby "3.4.9"

gem "rails", "~> 8.1.2"
gem "pg", ">= 1.5"
gem "puma", ">= 5.0"
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "bcrypt", "~> 3.1"
gem "solid_queue"
gem "solid_cache"
gem "solid_cable"
gem "kamal", require: false
gem "thruster", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false
gem "opentelemetry-api"
gem "opentelemetry-exporter-otlp"
gem "opentelemetry-instrumentation-action_pack"
gem "opentelemetry-instrumentation-active_job"
gem "opentelemetry-instrumentation-active_record"
gem "opentelemetry-instrumentation-active_support"
gem "opentelemetry-instrumentation-rack"
gem "opentelemetry-sdk"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "simplecov", require: false
  gem "capybara", require: false
  gem "selenium-webdriver", require: false
end
