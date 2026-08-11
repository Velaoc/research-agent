# Storefront deploy and operations contract

Vela Foundation M8 is a guest-first, digital-goods storefront. Prices are
integer cents from PostgreSQL; browsers never submit a trusted amount, price,
currency, success URL, or fulfillment instruction. Stripe Checkout handles
payment credentials, and the application never receives PAN or CVC data.

## Feature flag

`config/foundation.yml` enables the interactive module only when
`storefront_enabled` is the YAML boolean `true`. Strings such as `"true"`,
`1`, `false`, blank, and missing values are disabled. Disabled mode exposes no
catalog, cart, checkout, receipt, simulator, or storefront-admin affordance.

One narrow settlement exception is deliberate: the signed POST endpoint at
`/storefront/stripe/webhook` remains mounted with no UI. This allows an order
whose Stripe Checkout Session was created before an operator disabled the flag
to settle safely. It still returns 404 unless Stripe settlement readiness is
valid. Keep credentials/webhook registration until pending sessions are
drained; then they may be removed.

The supported fulfillment mode is exactly `storefront_fulfillment_mode:
digital`. Readiness rejects any other value. Inventory represents limited
digital licenses, seats, appointments, or capacity—not shippable units.
Live/production readiness also requires a customized application identity,
canonical domain, support/legal mailboxes, and the deliberate
`storefront_commerce_legal_reviewed: true` marker after the checklist below is
complete. The stock template cannot become a live store merely by adding
plausible-looking Stripe keys.

## Stripe environment

Provide these only through the deployment secret manager:

- `STOREFRONT_STRIPE_SECRET_KEY`: server-only `sk_live_...` or `sk_test_...`.
  The existing `STRIPE_PRIVATE_KEY` is a fallback for the API key.
- `STOREFRONT_STRIPE_WEBHOOK_SECRET`: the `whsec_...` secret for the dedicated
  storefront endpoint. Do not reuse Pay's subscription signing secret.
- `STOREFRONT_STRIPE_MODE`: `live` or `test`. Production defaults to `live`;
  the key prefix must match. Values containing placeholder markers are denied.
- `APP_HOST`: optional absolute trusted application origin for Checkout return
  URLs (required for preview Stripe mode). It must be an origin only: HTTPS,
  default port, and no credentials/path/query/fragment. Outside preview its
  host must exactly match the configured foundation domain. Until M9
  centralizes this contract, the configured domain is the fallback. User
  request hosts and submitted URLs are never used.

Register only relevant Checkout event types for this endpoint:
`checkout.session.completed`, `checkout.session.async_payment_succeeded`,
`checkout.session.async_payment_failed`, and `checkout.session.expired`.
Pay continues to own organization subscription events at
`/pay/webhooks/stripe`; storefront code intentionally uses a separate,
official-SDK-verified endpoint and ledger.

Checkout Sessions use an order-derived idempotency key, opaque order reference,
server-side `price_data`, and a fixed 45-minute expiry. Stock is reserved in a
transaction under deterministically ordered PostgreSQL row locks. Confirmed
expiry/cancellation releases it exactly once. Ambiguous Stripe connection/5xx
creation outcomes retain stock until reconciliation, because releasing while a
remote session might remain payable can oversell. Delayed unpaid methods have
a bounded 30-day reconciliation window. Verified current paid state is checked
against reference, session, amount, currency, email, and every line item before
idempotent fulfillment.

Every cart mutation rotates a server-generated nonce in the signed session
cookie. Its SHA-256 digest has a unique database constraint on orders. Duplicate
or concurrent submits return the same order while a losing transaction rolls
back its attempted stock decrement. New-order attempts are bounded per
normalized IP and session nonce in PostgreSQL under advisory locks; safe replay
of an existing order does not consume the throttle. Old throttle rows are
purged daily.

## Hosted preview

`VELA_HOLODEX_PREVIEW=1` defaults to
`STOREFRONT_PREVIEW_PAYMENT_MODE=simulator`. Simulator routes are 404 outside
that exact preview state. The simulator renders no card/CVC fields, makes no
Stripe request, labels every page and receipt as simulated, and stores provider
identifiers under `preview_simulator`, never `stripe`.

Holodex may explicitly use `STOREFRONT_PREVIEW_PAYMENT_MODE=stripe` with
`STOREFRONT_STRIPE_MODE=test`, an `sk_test_...` key, and webhook secret. Preview
live mode is always rejected. No fake key is generated or injected.

## Guest privacy, receipts, and mail

Checkout records email and versioned Terms/Privacy assent with timestamp, IP,
and a bounded user agent. An authenticated session may set `user_id`; email
matching never attaches ownership. Guests receive a purpose-bound signed
receipt capability expiring 24 hours after order creation. Receipt lookup uses
the non-sequential public reference and returns 404 on every authorization
failure.

Successful fulfillment queues `Foundation::Storefront::OrderReceiptJob`.
M8 supplies the network-free mailer boundary and content; M9 finalizes runtime
delivery configuration. Payment event rows store identifiers, outcomes, and a
payload digest—not raw provider payloads, card data, signatures, or secrets.
Receipt dispatch uses a database lease plus a five-minute repair sweep, and the
delivery job holds the order row lock so concurrent jobs do not both send.
Messages use a stable order-derived Message-ID. The email gets a fresh 24-hour
receipt capability even when delayed payment completes days after checkout.

## Catalog images and imports

Uploads use Active Storage and are byte-inspected with Marcel. PNG, JPEG, WebP,
and GIF up to 8 MB are accepted. Generic Active Storage/direct-upload routes
are disabled; active products expose a bounded image-serving action, and a
daily task purges unattached blobs older than 24 hours. External images require
HTTPS and an exact lowercase host in `storefront_external_image_hosts` (empty
by default). They are never fetched by the server and render with
`referrerpolicy="no-referrer"`; unlisted/local/private/literal hosts and
credential-bearing or non-HTTPS URLs are rejected.

The admin CSV importer accepts valid UTF-8 up to 1 MB and 500 data rows. It
requires `name` and exactly one row value from `price` or `price_cents`; optional
headers are documented on the admin page. It rejects unknown/duplicate headers,
formulas, malformed quoting, non-finite/floating cents, invalid types, and
unsafe image URLs. Each valid row commits independently, and the result page
reports every row error. It never evaluates data or reads URLs/filesystem paths.

## Operator launch checklist

- Replace the application identity/domain/support/legal placeholders.
- Populate `storefront_external_image_hosts` only for CDN origins you control,
  or leave it empty and use uploads.
- Keep `storefront_fulfillment_mode: digital`, or implement and test a complete
  physical-goods shipping/tax/legal system before changing it.
- Define delivery timing, access duration, regional restrictions, refund and
  statutory withdrawal handling, tax/VAT treatment, and support expectations.
- Review and version every `TODO-OPERATOR` in Terms and Privacy with counsel.
- Set `storefront_commerce_legal_reviewed: true` only after those reviews and
  delivery/refund/tax decisions are complete.
- Configure cloud Active Storage for production and its retention/deletion
  policy; local disk is not a multi-instance production store.
- Configure the dedicated Stripe secrets and events, then exercise live-mode
  readiness and a test-mode end-to-end checkout before launch.
- Run the web and job processes; monitor rejected payment events, reconciliation
  events, queue health, mail failures, pending reservations, and stock levels.
- Drain pending Checkout Sessions before disabling the module or rotating away
  its webhook credentials.
