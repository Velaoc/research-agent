source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Ruby 4 ships CSV as a bundled gem rather than a default library. The
# storefront's bounded, strict product importer uses its streaming parser.
gem "csv", "~> 3.3"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
# MIT-licensed; used on the operator machine, not required inside the app image.
gem "kamal", "~> 2.12", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# S3-compatible Active Storage (AWS S3, Cloudflare R2, MinIO, …). Apache-2.0.
# Selected only when ACTIVE_STORAGE_SERVICE names a service that uses it.
gem "aws-sdk-s3", require: false

# Foundation: operational healthcheck endpoint at /healthcheck [https://github.com/rameerez/allgood]
gem "allgood"

# Foundation: abort requests that exceed a wall-clock ceiling [https://github.com/zombocom/rack-timeout]
gem "rack-timeout", require: "rack/timeout/base"

# Foundation: restore real client IPs when served behind Cloudflare [https://github.com/modosc/cloudflare-rails]
gem "cloudflare-rails"

# Foundation: page titles, descriptions, and Open Graph tags [https://github.com/kpumuk/meta-tags]
gem "meta-tags"

# Foundation: sitemap generation for search engines [https://github.com/kjvarga/sitemap_generator]
gem "sitemap_generator"

# Foundation: email/password authentication [https://github.com/heartcombo/devise]
gem "devise"

# Foundation: Cloudflare Turnstile challenge on registration and password reset
# [https://github.com/instrumentl/rails-cloudflare-turnstile]
gem "rails_cloudflare_turnstile"

# Foundation: reject disposable email addresses at signup [https://github.com/rameerez/nondisposable]
gem "nondisposable"

# Foundation: OAuth sign-in (SPEC M3) — Google and GitHub strategies plus
# CSRF protection for the OmniAuth request phase, driven through Devise's
# :omniauthable module.
gem "omniauth-google-oauth2"
gem "omniauth-github"
gem "omniauth-rails_csrf_protection"

# Foundation: team workspaces with roles and invitations (SPEC M4)
# [https://github.com/rameerez/organizations]
gem "organizations"

# Foundation: organization-scoped subscriptions, entitlements, and revenue
# metrics (SPEC M5). Pay persists Stripe webhook state locally;
# pricing_plans resolves plan access; profitable reads Pay's local records.
gem "pay", "~> 11.7"
gem "stripe", "~> 19.0"
gem "pricing_plans", "~> 0.4"
gem "profitable", "~> 0.6"

# Foundation: operator-only administration, per-device session tracking, and
# Solid Queue visibility (SPEC M6). All three are MIT-licensed and support the
# Rails 8.1 / Ruby 4 foundation runtime.
gem "madmin", "~> 2.4.0"
gem "sessions", "~> 0.2.2"
gem "mission_control-jobs", "~> 1.1.0"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
