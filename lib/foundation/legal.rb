module Foundation
  # Single source of truth for the versions of the legal documents served at
  # /legal/terms and /legal/privacy. Bump a version (and its date) whenever
  # the corresponding document changes materially; signups store the versions
  # that were in force, so historical assent stays auditable.
  module Legal
    TERMS_VERSION = "v2"
    TERMS_UPDATED_ON = Date.new(2026, 8, 10)

    PRIVACY_VERSION = "v3"
    PRIVACY_UPDATED_ON = Date.new(2026, 8, 10)

    # Human-visible identifier rendered on the document, e.g. "v1 — 2026-08-10".
    def self.terms_label
      "#{TERMS_VERSION} — #{TERMS_UPDATED_ON.iso8601}"
    end

    def self.privacy_label
      "#{PRIVACY_VERSION} — #{PRIVACY_UPDATED_ON.iso8601}"
    end
  end
end
