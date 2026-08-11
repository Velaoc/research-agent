# Hosted runtime and mail

Vela reads deploy-time settings once, validates them, and freezes the result
while Rails boots. Controllers, mailers, Stripe return URLs, health checks, and
Puma process selection all consume that snapshot. Changing process environment
after boot has no effect; restart the application after changing runtime
configuration.

## Canonical public origin

`APP_HOST` accepts either a bare host (`shop.example.com`) or an absolute
HTTP(S) origin (`https://shop.example.com:8443`). It must not contain a path,
even `/`, or a query, fragment, credentials, backslash, whitespace, non-ASCII
text, or control character.

The scheme follows the host, not the Rails environment, because plaintext is
safe only where the traffic never leaves the machine:

- Loopback hosts — `localhost`, any `*.localhost` name, `127.0.0.0/8`, `::1`,
  and `0.0.0.0` — use `http`.
- Every other host uses `https`, and an explicit `http://` origin naming a
  routable host is rejected rather than silently downgraded.
- Production and hosted preview require HTTPS outright, so a loopback
  `APP_HOST` stops the boot there.

In production outside preview, the resolved host must be the `domain` from
`config/foundation.yml` or one of its subdomains. An injected `APP_HOST` can
therefore never move Stripe return URLs or emailed links to another domain. A
hosted preview is deliberately exempt: the hosting runtime assigns its
hostname, which cannot match the application's own domain.

When `APP_HOST` is absent, a deployed environment falls back to the `domain`
in `config/foundation.yml` over HTTPS. The `development` environment instead
falls back to `http://localhost:3000`, so a confirmation or password-reset
link clicked during local development stays on the developer's machine. Set
`APP_HOST` in development to exercise a real hostname.

This origin is the sole host for Devise confirmation, password-reset, and
unlock links, organization invitations, storefront receipts, and Stripe return
URLs. A browser's request `Host` header never changes generated links.

## Hosted preview

The hosting runtime, not a generated application, sets
`VELA_HOLODEX_PREVIEW=1`. The accepted values are exactly `1` and `0`; any
other configured value stops boot so a misspelled security mode cannot be
mistaken for production.

Preview mode has these fixed properties:

- Active Storage uses the local disk service.
- Every Rails response, including `/up`, `/healthcheck`, and error responses,
  carries `X-Robots-Tag: noindex`.
- Storefront checkout defaults to the clearly labeled local simulator and
  needs no Stripe configuration or network access.
- Without `SMTP_ADDRESS`, Action Mailer uses its in-memory test adapter and new
  email/password accounts are confirmed automatically.
- With `SMTP_ADDRESS`, ordinary Devise confirmation remains enabled and
  delivery uses the relay.

`STOREFRONT_PREVIEW_PAYMENT_MODE=stripe` is an optional opt-in to real Stripe
test mode. It requires an explicit `APP_HOST`, `STOREFRONT_STRIPE_MODE=test`, a
valid test secret key, and a distinct webhook signing secret. Preview rejects
live Stripe mode. `simulator` and `stripe` are the only accepted values.

## Outbound mail

The SMTP variables are provider-neutral:

| Variable | Contract |
|---|---|
| `SMTP_ADDRESS` | Relay DNS name; its presence selects SMTP. Single-label service names are allowed. |
| `SMTP_PORT` | Integer 1–65535; defaults to 587. |
| `SMTP_USERNAME` / `SMTP_PASSWORD` | Optional, but must be supplied together. Plain authentication is added only when the pair is present. |
| `SMTP_ENABLE_STARTTLS_AUTO` | Exact `true` or `false`; defaults to `true`. |
| `MAILER_FROM` | Exactly one mailbox, optionally with a display name; CR/LF and every other control character are rejected. Defaults to `support_email` in `config/foundation.yml`. |

For example, a hosting sidecar named `holodex` can be configured without TLS
or authentication:

```sh
SMTP_ADDRESS=holodex
SMTP_PORT=2525
SMTP_ENABLE_STARTTLS_AUTO=false
MAILER_FROM='Product Preview <noreply@preview.example>'
```

The application writes that identity to both From and Reply-To after every
mailer action, including Devise and organization mailers. A relay may rewrite
transport headers, but application code cannot accidentally emit another
product's identity. Delivery errors propagate to the web/job error pipeline in
SMTP and ordinary provider modes. The offline in-memory preview is the only
mode that suppresses delivery errors because it performs no network delivery.

When no deploy-time SMTP relay is present outside preview, production keeps the
explicit application provider in `config/environments/production.rb` (SMTP in
the unmodified foundation). Replace that provider deliberately if the generated
application adopts a provider-specific delivery gem.

## Database and queue topology

One `DATABASE_URL` is the default and complete production configuration. The
primary schema and migrations contain application, Active Storage, Solid
Queue, Solid Cache, and Solid Cable tables. `db:prepare` therefore prepares a
working deployment even on a platform that supplies no named database URLs.

Optional `QUEUE_DATABASE_URL`, `CACHE_DATABASE_URL`, and `CABLE_DATABASE_URL`
move only the named adapter to a separate database. Rails then prepares the
adapter's checked-in upstream schema in addition to the primary schema.

The normal topology runs `bin/jobs` separately. For a single web container,
set `SOLID_QUEUE_IN_PUMA=1`; use `0` or omit it for the external worker. Other
values stop Rails boot and never enable the Puma plugin.

## Storage and readiness

Preview always uses `local`, and test uses its isolated disk service. A real
production deployment sets `ACTIVE_STORAGE_SERVICE` to the lowercase name of a
cloud service configured in `config/storage.yml`. The secret-free production
fallback is local only so image builds and asset compilation can boot; it is
not launch-ready.

`/healthcheck` performs no test email and no Stripe network request. It reports:

- hosted preview active/inactive;
- mail relay, in-memory preview, or application-provider mode;
- the selected storage mode and an actual small write/delete probe;
- storefront simulator active/inactive;
- Solid Queue inside Puma or in an external worker;
- database connectivity and pending migrations;
- live queue heartbeat where Solid Queue is the active adapter; and
- local Stripe configuration readiness without contacting Stripe.

Outside preview in production, readiness fails until a configured non-disk
storage service is selected. It also retains the storefront's existing
fail-closed Stripe, identity, fulfillment, and legal-review checks.
