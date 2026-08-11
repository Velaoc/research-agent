# frozen_string_literal: true

require "ipaddr"
require "mail"
require "uri"

module Foundation
  # A validated snapshot of deploy-time settings. The application creates one
  # instance while it boots; request data and later ENV mutations never become
  # URL, mail, payment, storage, or process configuration.
  class RuntimeConfig
    class Invalid < StandardError; end

    RUNTIME_ENV_KEYS = %w[
      ACTIVE_STORAGE_SERVICE APP_HOST CABLE_DATABASE_URL CACHE_DATABASE_URL
      MAILER_FROM QUEUE_DATABASE_URL SMTP_ADDRESS SMTP_ENABLE_STARTTLS_AUTO
      SMTP_PASSWORD SMTP_PORT SMTP_USERNAME SOLID_QUEUE_IN_PUMA
      STOREFRONT_PREVIEW_PAYMENT_MODE VELA_HOLODEX_PREVIEW
    ].freeze
    DATABASE_ROLES = %i[cache queue cable].freeze
    PREVIEW_PAYMENT_MODES = %w[simulator stripe].freeze

    # Load balancers and uptime monitors reach the probe endpoints by IP or
    # internal hostname, which never matches config.hosts, so host
    # authorization must skip them. Shared with the test suite so the
    # exclusion is asserted rather than restated.
    HEALTH_PROBE_PATHS = ->(request) {
      request.path == "/up" || request.path.start_with?("/healthcheck")
    }.freeze

    # Only the local development loop may generate plaintext links, and only
    # to a host that never leaves the machine. Everything else is HTTPS.
    LOOPBACK_HOST_NAMES = %w[localhost 0.0.0.0].freeze
    LOOPBACK_HOST_SUFFIX = ".localhost"

    # A developer running `bin/rails server` with no deploy-time APP_HOST
    # needs confirmation and password-reset links that stay on the machine.
    # Every deployed environment falls back to the foundation.yml domain.
    DEVELOPMENT_ORIGIN = "http://localhost:3000"

    attr_reader :canonical_origin, :mailer_from, :preview_payment_mode,
      :smtp_settings, :storage_service

    def initialize(environment: ENV, foundation:, rails_environment:)
      @rails_environment = rails_environment.to_s.dup.freeze
      @preview = exact_preview_flag(environment["VELA_HOLODEX_PREVIEW"])
      @solid_queue_in_puma = exact_queue_flag(environment["SOLID_QUEUE_IN_PUMA"])
      @app_host_configured = environment["APP_HOST"].present?
      @canonical_origin = build_origin(environment["APP_HOST"], foundation.fetch(:domain)).freeze
      @url_options = build_url_options.freeze
      @mailer_from = parse_mailbox(environment["MAILER_FROM"].presence || foundation.fetch(:support_email)).freeze
      @smtp_settings = build_smtp_settings(environment)&.freeze
      @storage_service = parse_storage_service(environment["ACTIVE_STORAGE_SERVICE"])
      @separate_databases = DATABASE_ROLES.to_h do |role|
        [ role, environment["#{role.to_s.upcase}_DATABASE_URL"].present? ]
      end.freeze
      @preview_payment_mode = build_preview_payment_mode(environment).freeze
      freeze
    end

    def preview?
      @preview
    end

    def production?
      @rails_environment == "production"
    end

    def app_host_configured?
      @app_host_configured
    end

    def smtp?
      !smtp_settings.nil?
    end

    def offline_preview?
      preview? && !smtp?
    end

    def simulator?
      preview? && preview_payment_mode == "simulator"
    end

    def preview_stripe?
      preview? && preview_payment_mode == "stripe"
    end

    # The caller supplies the provider deliberately configured for its Rails
    # environment. Deploy-time SMTP and offline preview take priority over it.
    def mail_delivery_method(provider:)
      return :smtp if smtp?
      return :test if preview?

      provider.to_sym
    end

    def mail_mode(provider:)
      return "SMTP relay" if smtp?
      return "in-memory preview" if preview?

      "#{provider} application provider"
    end

    def raise_delivery_errors?
      !offline_preview?
    end

    def active_storage_service
      return :local if preview?
      return storage_service if storage_service
      return :test if @rails_environment == "test"

      # Production can boot and compile assets without cloud credentials, but
      # readiness rejects this disk fallback before serving real traffic.
      :local
    end

    def storage_mode
      return "local preview disk" if preview?
      return storage_service.to_s if storage_service
      return "test disk" if @rails_environment == "test"
      return "local development disk" unless production?

      "unconfigured production disk fallback"
    end

    def production_storage_configured?
      !production? || preview? || (storage_service && !%i[local test].include?(storage_service))
    end

    def url_options
      @url_options
    end

    def solid_queue_in_puma?
      @solid_queue_in_puma
    end

    def queue_mode
      solid_queue_in_puma? ? "inside Puma" : "external worker"
    end

    def separate_database?(role)
      @separate_databases.fetch(role.to_sym)
    end

    def database_role(role)
      separate_database?(role) ? role.to_sym : :primary
    end

    def inspect
      "#<#{self.class.name} preview=#{preview?} origin=#{canonical_origin.inspect} " \
        "mail=#{smtp? ? 'smtp' : 'provider'} storage=#{storage_mode.inspect} " \
        "queue=#{queue_mode.inspect}>"
    end

    # Hosts Rails may accept in production (config.hosts). A hosted preview
    # is assigned its hostname at run time via APP_HOST and that name never
    # matches the product domain, so it is allowed exactly. Everywhere else
    # the leading-dot form permits the foundation.yml domain and every
    # subdomain — the same boundary enforce_canonical_domain applies to
    # generated links.
    def allowed_request_hosts(foundation_domain:)
      if preview?
        [ URI.parse(canonical_origin).hostname ].freeze
      else
        [ ".#{normalize_host(foundation_domain)}" ].freeze
      end
    end

    private

    def exact_preview_flag(value)
      return false if value.nil? || value == "0"
      return true if value == "1"

      raise Invalid, "VELA_HOLODEX_PREVIEW must be exactly 1 or 0"
    end

    def exact_queue_flag(value)
      return false if value.nil? || value == "0"
      return true if value == "1"

      # Refuse to start instead of accidentally running two queue supervisors
      # or silently ignoring an operator typo.
      raise Invalid, "SOLID_QUEUE_IN_PUMA must be exactly 1 or 0"
    end

    def exact_starttls(value)
      return true if value.nil?
      return true if value == "true"
      return false if value == "false"

      raise Invalid, "SMTP_ENABLE_STARTTLS_AUTO must be exactly true or false"
    end

    def build_origin(configured, foundation_domain)
      raw = configured.presence || fallback_origin(foundation_domain)
      if raw.blank? || !raw.ascii_only? || raw != raw.strip || raw.match?(/[[:cntrl:]\\]/)
        raise Invalid, "APP_HOST must be a bare host or absolute HTTP(S) origin"
      end

      uri = parse_origin(raw)
      # URI#host keeps the brackets around an IPv6 literal; #hostname does not.
      valid = uri.is_a?(URI::HTTP) && uri.hostname.present? && uri.userinfo.nil? &&
        uri.path.to_s.empty? && uri.query.nil? && uri.fragment.nil? && valid_host?(uri.hostname)
      unless valid
        raise Invalid, "APP_HOST must not contain credentials, a path, query, or fragment"
      end

      scheme = uri.scheme.downcase
      host = normalize_host(uri.hostname)
      if scheme != "https" && !loopback_host?(host)
        raise Invalid, "APP_HOST may use plain HTTP only for a loopback development host"
      end
      if (production? || preview?) && scheme != "https"
        raise Invalid, "APP_HOST must use HTTPS in preview and production"
      end
      enforce_canonical_domain(host, foundation_domain)

      default_port = scheme == "https" ? 443 : 80
      "#{scheme}://#{canonical_host(host)}#{":#{uri.port}" unless uri.port == default_port}"
    rescue URI::InvalidURIError, URI::InvalidComponentError
      raise Invalid, "APP_HOST must be a bare host or absolute HTTP(S) origin"
    end

    # Deployed environments publish the canonical product domain; only the
    # local development loop keeps its links on the developer's machine.
    def fallback_origin(foundation_domain)
      return DEVELOPMENT_ORIGIN if @rails_environment == "development"

      foundation_domain.to_s
    end

    # The scheme is chosen before parsing: parsing a bare "localhost" as HTTPS
    # first would adopt port 443 and then emit "http://localhost:443".
    def parse_origin(raw)
      return URI.parse(raw) if raw.match?(%r{\A[a-z][a-z0-9+.-]*://}i)

      probe = URI.parse("https://#{raw}")
      scheme = probe.hostname.present? && loopback_host?(normalize_host(probe.hostname)) ? "http" : "https"
      URI.parse("#{scheme}://#{raw}")
    end

    # A production deployment may be reached at the foundation.yml domain or
    # one of its subdomains and nowhere else, so an injected APP_HOST can
    # never move payment return URLs or emailed links to another domain.
    # Hosted previews are exempt: their hostname is assigned at run time.
    def enforce_canonical_domain(host, foundation_domain)
      return unless production? && !preview?

      canonical = normalize_host(foundation_domain.to_s.sub(%r{\A[a-z][a-z0-9+.-]*://}i, "")
        .split("/").first.to_s.sub(/:\d+\z/, ""))
      return if canonical.blank? || host == canonical || host.end_with?(".#{canonical}")

      raise Invalid, "APP_HOST must be the configured domain or one of its subdomains"
    end

    def normalize_host(host)
      host.to_s.downcase.delete_suffix(".")
    end

    def loopback_host?(host)
      return true if LOOPBACK_HOST_NAMES.include?(host) || host.end_with?(LOOPBACK_HOST_SUFFIX)

      IPAddr.new(host).loopback?
    rescue IPAddr::InvalidAddressError
      false
    end

    def valid_host?(host)
      normalized = normalize_host(host)
      return false if normalized.blank? || normalized.length > 253

      IPAddr.new(normalized)
      true
    rescue IPAddr::InvalidAddressError
      normalized.split(".").all? do |label|
        label.length.between?(1, 63) && label.match?(/\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/i)
      end
    end

    def canonical_host(host)
      host.include?(":") ? "[#{host}]" : host
    end

    def build_url_options
      uri = URI.parse(canonical_origin)
      options = { host: uri.host.freeze, protocol: "#{uri.scheme}://".freeze }
      default_port = uri.scheme == "https" ? 443 : 80
      options[:port] = uri.port unless uri.port == default_port
      options
    end

    def parse_mailbox(value)
      raw = value.to_s
      raise Invalid, "MAILER_FROM must not contain control characters" if raw.match?(/[[:cntrl:]]/)

      addresses = Mail::AddressList.new(raw).addresses
      address = addresses.one? && addresses.first
      valid = address && address.address.present? && address.address.match?(/\A[^@\s]+@[^@\s]+\z/)
      raise Invalid, "MAILER_FROM must contain exactly one valid mailbox" unless valid

      address.to_s
    rescue Mail::Field::ParseError
      raise Invalid, "MAILER_FROM must contain exactly one valid mailbox"
    end

    def build_smtp_settings(environment)
      address = environment["SMTP_ADDRESS"].presence
      related = %w[SMTP_PORT SMTP_USERNAME SMTP_PASSWORD SMTP_ENABLE_STARTTLS_AUTO]
      if address.nil?
        if related.any? { |name| environment[name].present? }
          raise Invalid, "SMTP settings require SMTP_ADDRESS"
        end

        return nil
      end
      if address != address.strip || !address.ascii_only? ||
          !address.match?(/\A[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\z/i)
        raise Invalid, "SMTP_ADDRESS is invalid"
      end

      username = environment["SMTP_USERNAME"].presence
      password = environment["SMTP_PASSWORD"].presence
      if username.present? != password.present?
        raise Invalid, "SMTP_USERNAME and SMTP_PASSWORD must be configured together"
      end

      settings = {
        address: address.dup.freeze,
        port: integer_port(environment.fetch("SMTP_PORT", "587")),
        enable_starttls_auto: exact_starttls(environment["SMTP_ENABLE_STARTTLS_AUTO"]),
        open_timeout: 5,
        read_timeout: 5
      }
      if username
        settings.merge!(
          user_name: username.dup.freeze,
          password: password.dup.freeze,
          authentication: :plain
        )
      end
      settings
    end

    def integer_port(value)
      port = Integer(value, 10)
      unless port.between?(1, 65_535)
        raise Invalid, "SMTP_PORT must be between 1 and 65535"
      end

      port
    rescue ArgumentError, TypeError
      raise Invalid, "SMTP_PORT must be between 1 and 65535"
    end

    def parse_storage_service(value)
      return nil if value.blank?
      unless value.match?(/\A[a-z][a-z0-9_]*\z/)
        raise Invalid, "ACTIVE_STORAGE_SERVICE must be a simple lowercase service name"
      end

      value.to_sym
    end

    def build_preview_payment_mode(environment)
      return "inactive" unless preview?

      mode = environment.fetch("STOREFRONT_PREVIEW_PAYMENT_MODE", "simulator")
      unless PREVIEW_PAYMENT_MODES.include?(mode)
        raise Invalid, "STOREFRONT_PREVIEW_PAYMENT_MODE must be simulator or stripe"
      end

      mode
    end
  end
end
