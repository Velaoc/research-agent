# Vela Foundation — product specification

Version 1.0 — 2026-08-10.

This document is the sole bridge between Vela's product requirements and the
implementation. It describes BEHAVIOR and acceptance criteria. Implementers
work from this spec plus public documentation only (Rails guides, gem
READMEs, Google's Material Design 3 spec, Stripe docs) and from no other
source. The binding development protocol, including the excluded-source
list, is maintained outside this repository so that no third-party name
ships inside a generated application; see `CLEANROOM_PROTOCOL.md` in the
build workspace.

The repository is a **starter template**: Vela's `create_rails_app`
generates each new application from it. Everything here ships under a real
MIT license, and every file in this repository is copied into generated
applications — so no file here may contain a third-party product name,
brand, or attribution.

## Global conventions

- Rails 8.1 defaults are the base: propshaft, importmap, Hotwire,
  solid_queue/solid_cache/solid_cable, Thruster, the generated production
  Dockerfile, Brakeman, rubocop-rails-omakase, GitHub CI.
- PostgreSQL in every environment. Tailwind CSS v4 for styling.
- Namespace original foundation code under `Foundation` (Ruby) and
  `foundation--*` (Stimulus identifiers). App-facing config lives in
  `config/foundation.yml` exposed as `Rails.configuration.x.foundation`
  (product identity: application_name, logo_url, brand seed color, default
  page title/description/OG image, social links, support/legal mailboxes,
  domain).
- Every milestone lands with tests, and the full production gate green:
  RuboCop zero offenses, Brakeman zero warnings, bundler-audit clean,
  importmap audit clean, full test suite passing inside the Docker `test`
  stage (below).
- No emoji or flag glyphs in UI. Icons come exclusively from the locally
  subset Material Symbols Rounded font: no other icon library, icon gem,
  icon font, or SVG icon pack may be added as a dependency or asset.
- All gems must carry a permissive license — MIT, Apache-2.0, BSD-2/3, or
  ISC — and come from rubygems.org. (ISC is included because it is the
  BSD-2-equivalent license used by `rails_cloudflare_turnstile`.)

## M1 — Production base and gates

1. Multi-stage production Dockerfile (the generated one), extended with a
   `test` stage that: installs full gems, provisions a throwaway
   PostgreSQL cluster inside the stage, runs `db:prepare`, RuboCop,
   bundler-audit, importmap audit, Brakeman (exit on warn), and
   `rails test`. This stage is the contract Holodex's `verify_repo` builds.
2. `/up` (Rails default) plus an `allgood` healthcheck endpoint at
   `/healthcheck` covering: database connectivity, pending migrations,
   queue liveness, and disk-backed storage writability.
3. `rack-timeout` with a sane production wall-clock ceiling (~15s) and
   `cloudflare-rails` so real client IPs resolve behind Cloudflare.
4. `meta-tags` for titles/descriptions/OG defaults from foundation.yml;
   `sitemap_generator` with a production sitemap task; robots.txt allows
   crawling only in production domains, and preview hosts send
   `X-Robots-Tag: noindex` (see M9).
5. MIT LICENSE (full text, "Copyright (c) 2026 novaoc"). README explains
   the template's purpose, local setup, and self-hosting.

Acceptance: gate green from a clean clone with no secrets present
(`SECRET_KEY_BASE_DUMMY=1` asset precompile works).

## M2 — Accounts and legal assent

1. Devise-based email auth: registration, login, logout, password reset,
   **email confirmation required**, account lockout after repeated
   failures, minimum password length 12.
2. Cloudflare Turnstile on registration (and password reset), via
   `rails_cloudflare_turnstile`; disabled cleanly in test.
3. Disposable-email rejection on registration via `nondisposable`.
4. Versioned legal assent:
   - Substantive Terms of Service and Privacy Policy pages served at
     `/legal/terms` and `/legal/privacy`, written fresh for this template,
     each carrying a visible version identifier and "last updated" date.
     Topics the documents must cover — terms: operator identity
     placeholder, service description, accounts/eligibility & minimum age,
     acceptable use, purchases/refunds placeholder, IP ownership,
     termination, disclaimers/liability limits, governing-law placeholder,
     change process; privacy: data collected (account, orders, sessions,
     technical), purposes, lawful bases placeholder, processors/service
     providers list placeholder, cookies/analytics, retention, user
     rights, contact mailbox, international transfer placeholder.
     Placeholders are clearly marked `TODO-OPERATOR` so a self-hoster
     must review before launch; README says the documents are a starting
     point, not legal advice.
   - Registration requires an explicit checkbox assent; the account
     record stores accepted terms version, privacy version, timestamp,
     request IP, user agent, and context ("signup").
   - A test asserts both documents exist, exceed a substance threshold
     (≥ 60 non-blank lines each), carry version identifiers, and that
     signup persists the acceptance record.
5. Preview auto-confirmation rule (see M9): when the app runs as a hosted
   preview WITHOUT an SMTP relay, new accounts are confirmed immediately;
   with a relay present, normal confirmation email flow applies.

## M3 — OAuth sign-in with safe account linking

1. Google and GitHub OAuth via omniauth (+
   `omniauth-rails_csrf_protection`).
2. Identities are stored per (provider, uid) with the owning user.
3. Linking rules (the security contract):
   - Signing in with a known identity signs in its user.
   - A signed-in user may explicitly connect/disconnect providers from
     their settings page.
   - An OAuth sign-in whose email matches an existing local account is
     NEVER auto-merged: the user is sent to sign in with their existing
     credentials first, then may link explicitly.
   - New OAuth users get accounts marked confirmed (provider verified the
     email) and must still record legal assent before the account is
     created (interstitial assent step).
4. Tests cover: identity sign-in, explicit link, explicit unlink (blocked
   when it would leave zero sign-in methods), and the no-auto-merge rule.

## M4 — Organizations

1. Team workspaces via the `organizations` gem: each user gets a personal
   organization at signup (skipped when signing up through an
   invitation); users can create additional organizations, switch between
   them, rename, and delete (owner only, with confirmation).
2. Roles: owner, admin, member. Invitations by email with signed tokens:
   accepting while signed out routes through signup (which then joins the
   invited organization instead of creating a personal one).
3. Ownership transfer and member removal with confirmation dialogs;
   leaving an organization is blocked for its only owner.
4. Current-organization scoping helper for app code
   (`Current.organization`), persisted per session.

## M5 — Billing and plans

1. Stripe subscription billing via `pay`, plan definitions via
   `pricing_plans` config: at least `free`, `pro`, `enterprise` example
   tiers with monthly/yearly prices, feature limits expressed as plan
   entitlements the app can query (`plan_allows?(:feature)` style).
2. Public pricing page renders the tiers from configuration with an
   interval toggle; checkout goes through Stripe Checkout; a billing
   portal link lets subscribers manage/cancel; webhooks (via pay) keep
   subscription state current.
3. Manual plan assignment (admin action) overrides subscription-derived
   plans; the UI marks manually assigned plans and hides self-serve
   upgrade CTAs for them; mixed state (manual plan + live Stripe
   subscription) still exposes billing management.
4. Organization-scoped: the organization is the billable entity.
5. Revenue/metrics console helpers via `profitable`.
6. Tests cover plan resolution precedence (manual > subscription > free),
   entitlement queries, CTA visibility rules, and webhook-driven state
   changes (stubbed Stripe).

## M6 — Admin

1. `madmin`-based admin at `/admin/dashboard`, gated to `User#admin?`
   (no self-serve path to admin; first admin is created from the
   console).
2. Resources: users (with lock/unlock, plan assignment), organizations
   (members, plan source), invitations, sessions/devices (via `sessions`
   gem: device, IP, last seen; revoke), storefront products and orders
   (M8).
3. Admin actions are audit-logged to the Rails log with actor ids.
4. `mission_control-jobs` mounted under admin for queue visibility.

## M7 — Material Design 3 system

The design system implements Google's MD3 spec directly (m3.material.io):

1. Semantic tokens as CSS custom properties for the full MD3 color system
   (primary/secondary/tertiary/error/surface families with on-*,
   containers, outline, inverse), generated for light AND dark schemes
   from one brand seed color in foundation.yml; typography scale
   (display/headline/title/body/label sizes per spec); shape scale
   (corner radii xs→full); elevation levels; state-layer opacities.
   Tailwind v4 maps utilities onto these tokens (e.g. `bg-md-primary`,
   `text-md-on-surface`).
2. Material Symbols Rounded via a helper: `material_symbol(:name, size:,
   fill:, class:)` rendering the icon font glyph with `aria-hidden` by
   default and optional accessible label. Font self-hosted through the
   asset pipeline (no runtime Google Fonts dependency), subset stated in
   docs.
3. Components as ERB partials + Stimulus controllers under the
   foundation namespace: buttons (filled, tonal, outlined, text; 48px
   min target), icon buttons, cards (elevated/filled/outlined), text
   fields (outlined, with error states wired to Rails validations),
   select, checkbox/switch, chips, dialogs (modal, focus-trapped), menus,
   snackbar (flash messages render as MD3 snackbars), top app bar,
   navigation: bottom bar (compact), rail (medium/expanded), drawer
   (large+) — the SAME nav items adapt across breakpoints.
4. Adaptive layout contract: compact <600, medium 600–839, expanded
   840–1199, large 1200–1599, extra-large ≥1600. Panes reflow (list-detail
   becomes two-pane at expanded+); navigation swaps component class, not
   just scale.
5. Accessibility contract: 48×48 CSS px minimum targets, visible focus
   indicators, WCAG AA contrast in both schemes, `prefers-reduced-motion`
   respected (no essential motion), browser zoom unbroken to 200%,
   keyboard operability for all interactive components; concise labels.
6. Dark/light follows `prefers-color-scheme` with a manual override
   toggle persisted per user.
7. App shell: authenticated layout (top bar + adaptive nav + content
   pane), public layout (marketing top bar + footer with legal links),
   Devise views restyled as MD3, error pages (404/422/500) branded.
8. Marketing set (public root when no product overrides it): hero with
   CTA, features grid, pricing section (from M5 config), FAQ
   (disclosure pattern), footer. Deliberately minimal.
9. `docs/MATERIAL_DESIGN_3.md`: how the token system works, component
   inventory with usage snippets, breakpoint/a11y rules, how to re-seed
   brand color. (Vela's prompt tells generated apps to read this file.)

## M8 — Storefront (optional module, on by default in template)

Feature-flagged by `foundation.yml` (`storefront_enabled`).

1. Catalog: products with name, slug, description, price_cents,
   currency, active flag, position, and an image (Active Storage upload
   OR external image_url). Public feed at `/storefront/products` as an
   MD3 adaptive grid; product detail page with buy affordance and
   image alt text from description.
2. Orders: order + line items, statuses pending → paid → fulfilled (plus
   canceled/refunded), amounts always computed server-side from product
   prices — client-provided amounts are never trusted.
3. **Guest-first checkout**: no account required. Checkout collects and
   validates an email (signed-in users' email is used automatically);
   quantity capped (1–10). Terms and Privacy links are visible at
   checkout (as well as signup and the footer).
4. Real deployments: Stripe Checkout session with server-set amounts and
   a signed order-return token; fulfillment happens ONLY through the
   Stripe webhook, which verifies signature, session, client reference,
   amount, and currency, idempotently.
5. Receipt access: `/storefront/orders/:id` requires the owning
   signed-in user OR a signed, expiring (24h) access token included in
   checkout redirects and receipts. Guests can always reach their receipt
   through that link; unauthorized access 404s.
6. Preview simulator (M9 environments only): when the app runs as a
   hosted preview, checkout redirects to a local "Simulate checkout" page
   (explicitly labeled test mode: no money moves, no card data entered or
   stored, no Stripe contact) whose confirm action marks the order paid
   and fulfills it. Simulator routes 404 outside preview mode.
7. Signed-in landing: when the storefront is enabled, root (signed-out
   and signed-in) is the product catalog, never an inherited dashboard.
   Navigation shows "Shop"; pricing/marketing links hide.
8. Admin: product CRUD with image upload validation (PNG/JPEG/WebP/GIF ≤
   8MB), CSV bulk import (header row; name+price required; price as
   dollars or cents; slug/currency/description/image_url/active/position
   optional; upsert by slug; per-row error reporting without rolling back
   valid rows), and order management views.
9. Readiness: with the storefront enabled outside preview mode, boot
   fails loudly when Stripe keys are missing or look like placeholders
   (values containing markers such as `placeholder`, `your_`, `dummy`,
   `no_egress`, `disabled` are rejected); in preview mode the storefront
   reports "test simulator" readiness instead and requires NO Stripe
   configuration.

## M9 — Hosted preview mode and mail

`VELA_HOLODEX_PREVIEW=1` marks a hosted, daily-wiped, no-egress preview
(injected by the Holodex runtime; a generated app never sets it itself).

1. Preview mode: Active Storage uses local disk (production otherwise
   uses the configured cloud service); `X-Robots-Tag: noindex` on all
   responses; no Stripe requirement (M8.9); checkout uses the simulator
   (M8.6).
2. Mail: provider-neutral SMTP from environment (`SMTP_ADDRESS`,
   `SMTP_PORT` default 587, optional `SMTP_USERNAME`/`SMTP_PASSWORD`
   with plain auth only when a username is present,
   `SMTP_ENABLE_STARTTLS_AUTO` default true, `MAILER_FROM`). Priority:
   SMTP env present → :smtp; else preview → :test (in-memory); else the
   app's configured production provider. Delivery errors raise except in
   offline preview.
   Mail sender defaults to `MAILER_FROM` when present, else the
   foundation support mailbox; mail headers must never carry another
   application's identity (the hosting relay may rewrite From/Reply-To;
   the app itself sends only its own identity).
   URL host for ALL generated links (confirmation, password reset,
   receipts): `ENV["APP_HOST"]` when present (the deploy runtime injects
   the app's real public hostname), else the foundation.yml domain.
3. Auto-confirmation (M2.5) applies only when preview mode is on AND no
   SMTP relay is configured.
4. Readiness endpoint reflects preview state truthfully (storage local,
   mail relay vs in-memory, simulator active).
5. Tests cover: mail method selection matrix, auto-confirm matrix,
   robots header, simulator gating.

## M10 — Template ergonomics for Vela

1. A `bin/rename` script that stamps a new product identity
   (application_name, slug, module name) across foundation.yml, PWA
   manifest, and README — the first thing Vela runs after cloning.
2. PWA manifest + square maskable icon placeholder generated from the
   brand seed color; instructions for replacing the mark.
3. Seeds: none required to boot; storefront demo products seeded only in
   development or preview.
4. README sections: what this template provides, quickstart, self-host
   guide (env vars incl. Stripe + SMTP + OAuth), Holodex preview notes,
   legal-review checklist, license (MIT).

## M14 — Native mobile shell server contract

Server half of a Hotwire Native shell. Built from public Hotwire Native,
Apple Universal Links, Google Digital Asset Links, and Rails 8.1
documentation only. Coexists with the M10 PWA manifest.

1. **Versioned, per-platform path configuration.** JSON documents at
   `/native/configurations/ios/v1` and `/native/configurations/android/v1`
   (Hotwire Native `settings` + `rules` shape). The version is part of the
   URL so a shipped binary pins a contract; unknown versions 404. Separate
   iOS and Android documents.
2. **Native entry and auth handoff.** `/native/entry` hands an authenticated
   web session to the shell (turbo-rails `recede_or_redirect_to`); guests
   land on `/native/auth`, a native-only MD3 sign-in screen (Material
   Symbols only, no emoji). Successful native sign-in returns through
   entry. Ordinary Devise/OmniAuth controllers remain the credential path.
3. **Current-user poll.** `GET /native/session` returns JSON
   `{ signed_in, user: { id, email } | null }` for the shell. It does not
   create or destroy sessions.
4. **Durable web-view sign-in.** Native password and OAuth sign-in always
   set Devise's `remember_user_token` (`:rememberable`). Persistence is the
   WebView cookie jar (session cookie + remember cookie; `Secure` under
   `force_ssl`). No custom native token. Cookie behaviour is documented in
   `docs/native/SERVER_CONTRACT.md`.
5. **Deep-link association files.** Public, unauthenticated:
   `/.well-known/apple-app-site-association` (and root
   `/apple-app-site-association`) and `/.well-known/assetlinks.json`, with
   `Content-Type: application/json`. Contents come only from
   `config/foundation.yml` → `native` (ios_app_id, ios_paths,
   android_package_name, android_sha256_cert_fingerprints). Unconfigured
   identifiers yield **404** (never a crash, never a placeholder Team ID).
6. **Native-shell gate.** Every native-only behaviour requires a User-Agent
   matching turbo-rails `hotwire_native_app?` (`/(Turbo|Hotwire) Native/`).
   Ordinary browsers receive 404 for path configuration, entry, auth, and
   session poll. Association files stay public for OS verifiers. Tests
   prove browsers never receive native-only behaviour.
7. **No security bypass.** Step-up reauthentication (M11) still gates
   sensitive mutations for native UAs. Host authorization is not widened
   for association files; they remain reachable on the product domain.
   PWA manifest at `/manifest.webmanifest` keeps working.

Acceptance: full gate green; browser-isolation test red against any leak of
native-only responses; association unconfigured→404 and configured→JSON
covered; host-authorization coverage for association paths on the product
domain; `docs/native/SERVER_CONTRACT.md` present.

## B2 — CRM capability (optional module, on by default in template)

Organization-scoped CRM primitives as a first-class omittable module
(`config/foundation/modules/crm.yml`). Designed as application
infrastructure reused across verticals, not a single industry's feature set.

1. **Models.** Contact, Company, Lead, Opportunity, Pipeline,
   PipelineStage, Activity, Note, Task, Tag, and Tagging. Tables use the
   `crm_` prefix. Every row belongs to an organization (FK to core).
2. **Behaviour.** Lead and opportunity ownership/assignment (owners must
   be members of the current organization), opportunity pipeline stage
   movement (status follows closed-won/closed-lost stages), notes and
   tasks on core records, and an activity timeline that records creates,
   assignments, stage changes, notes, and task events. Listing surfaces
   support simple query and ownership/status filters with offset
   pagination.
3. **UI.** Authenticated MD3 CRUD under `/crm` for the core records, a
   per-record timeline (notes, tasks, activity), pipeline/stage
   management, and a workspace overview. Navigation exposes a CRM item
   when the module is present.
4. **Organization isolation (security).** Every query is scoped
   server-side through the current organization. Probing an id from
   another organization is indistinguishable from a nonexistent id
   (404). Cross-organization isolation tests cover index leakage, show,
   update, destroy, assignment, stage movement, and notes.
5. **Module packaging.** Owned paths, host-file markers, table prefixes,
   and residue patterns allow `bin/foundation-modules omit crm` to leave
   a working application with no CRM residue.
6. **Deferred.** Drag-and-drop kanban, full-text search, bulk operations,
   import/export, and reporting are out of scope for this milestone.

Acceptance: full gate green with CRM included; omit crm succeeds with a
clean residue scan; isolation tests red against any cross-tenant read or
mutation.

## Verification gates (run for every milestone)

1. Docker `test` stage green (M1.1).
2. Similarity guard reports zero non-null-model matches against the
   reference corpus (tooling and corpus live outside this repository; see
   the build workspace protocol).
3. Brand scan: the excluded-name list from the build protocol returns no
   hits anywhere in this repository, including documentation.
4. Gemfile diff review: every new gem carries a permissive license per the
   Global conventions.
5. Provenance log entry in `PROVENANCE.md`: date, milestone, implementer
   (agent/session), inputs used.
