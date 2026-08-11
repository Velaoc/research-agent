# Self-host deploy (Kamal)

This is the production ship path for a generated application: build the
multi-stage `Dockerfile`, push an image, and run it behind Kamal’s proxy with
Thruster and Puma. It is separate from hosted preview.

| Path | Who sets it up | Flag | Storage | Mail | Payments |
|---|---|---|---|---|---|
| Self-host (this doc) | You, on your servers | unset / `0` | cloud via `ACTIVE_STORAGE_SERVICE` | SMTP or app provider | real Stripe when storefront/billing enabled |
| Hosted preview | Holodex runtime only | `VELA_HOLODEX_PREVIEW=1` | local disk | in-memory unless SMTP is set | simulator (or explicit test Stripe) |

Do not set `VELA_HOLODEX_PREVIEW` in `config/deploy.yml`. Preview behavior,
`X-Robots-Tag: noindex`, and the checkout simulator are documented in
[`HOSTED_RUNTIME.md`](HOSTED_RUNTIME.md). Mixing the two stories produces a
boot that looks healthy and a shop that cannot take real money — or the reverse.

## Why Kamal

The image already starts with Thruster (`Dockerfile` `CMD`), and the README
names Kamal as the container deploy tool. Kamal is MIT-licensed
(`gem "kamal"`). No other deploy adapter ships in-tree; any OCI host can still
run the image by hand if you inject the same environment.

## Prerequisites

1. A Linux host with Docker and SSH, reachable on ports 80 and 443 for the
   proxy’s Let’s Encrypt challenge (or your own certificates).
2. Local Docker and Ruby matching `.ruby-version`, with gems installed
   (`bundle install`) so `bin/kamal` runs on the operator machine.
3. A container registry Kamal can push to (Docker Hub, GHCR, or a private
   registry). The stock `config/deploy.yml` points at `localhost:5555` only as
   a placeholder.
4. PostgreSQL reachable from the app containers (`DATABASE_URL`), or the
   commented `db` accessory in `config/deploy.yml`.
5. S3-compatible object storage. Production readiness rejects the disk
   fallback outside preview.
6. Product identity stamped: `bin/rename` so `config/foundation.yml` `domain`
   is your real hostname. Production `config.hosts` is derived from that
   domain; an unstamped `example.com` fails readiness and refuses foreign
   Host headers.

## Configure

Edit `config/deploy.yml`:

- `servers.web` — SSH targets.
- `proxy.host` — public hostname; must equal `domain` in
  `config/foundation.yml` or be a subdomain of it.
- `env.clear.APP_HOST` — same host (or `https://…` origin). Boot fails if it
  drifts off the configured domain.
- `env.clear.ACTIVE_STORAGE_SERVICE` — `amazon` selects the S3 service in
  `config/storage.yml`. Set `AWS_REGION`, `S3_BUCKET`, and optionally
  `S3_ENDPOINT` (R2/MinIO) in clear or secret env as appropriate.
- `image` / `registry` — where the built image is stored.
- `SOLID_QUEUE_IN_PUMA` — exactly `"1"` (in-Puma supervisor) or `"0"` plus a
  `job` role running `bin/jobs`. Other values stop boot.

Wire secrets in `.kamal/secrets` via env or command substitution (see the
file). Minimum for a boot that can pass readiness:

| Secret / env | Role |
|---|---|
| `RAILS_MASTER_KEY` | Decrypt credentials; session signing if no `SECRET_KEY_BASE`. |
| `DATABASE_URL` | PostgreSQL for app, Solid Queue, Cache, and Cable tables. |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Object storage when using `amazon`. |
| `SMTP_*` / `MAILER_FROM` | Outbound mail; see [`HOSTED_RUNTIME.md`](HOSTED_RUNTIME.md). |
| Stripe / OAuth / Turnstile keys | As required by billing, storefront, and auth; README table. |

Optional split databases: `QUEUE_DATABASE_URL`, `CACHE_DATABASE_URL`,
`CABLE_DATABASE_URL`. Never commit filled secret values; the checked-in
`.kamal/secrets` only contains substitutions.

Storefront live mode additionally needs
`storefront_commerce_legal_reviewed: true` in `config/foundation.yml` and
valid Stripe keys — readiness stays red until both are done
([`STOREFRONT.md`](STOREFRONT.md)).

## Deploy

```sh
# One-time host bootstrap (Docker install via Kamal, proxy, accessories)
bin/kamal setup

# Build, push, migrate (db:prepare on web start), roll the container
bin/kamal deploy

# Useful aliases from config/deploy.yml
bin/kamal logs
bin/kamal console
bin/kamal app exec --interactive --reuse "bash"
```

First web boot runs `bin/rails db:prepare` from `bin/docker-entrypoint`.
Promote an operator only from the console (`User#admin?`); nothing in deploy
creates one.

## Verify

- `https://<proxy.host>/up` — process is up (Kamal’s deploy healthcheck).
- `https://<proxy.host>/healthcheck` — full readiness: database, migrations,
  queue heartbeat, storage write probe, mail mode, storefront/Stripe checks.
  A 503 here means the app is running but not launch-ready; read the page.
- Confirm `APP_HOST` links in a password-reset email match your domain.

## Hand-run image (no Kamal)

```sh
docker build -t my-app .
docker run --rm -p 80:80 \
  -e RAILS_MASTER_KEY=… \
  -e DATABASE_URL=postgres://… \
  -e APP_HOST=example.com \
  -e ACTIVE_STORAGE_SERVICE=amazon \
  -e AWS_ACCESS_KEY_ID=… \
  -e AWS_SECRET_ACCESS_KEY=… \
  -e AWS_REGION=us-east-1 \
  -e S3_BUCKET=… \
  -e SOLID_QUEUE_IN_PUMA=1 \
  my-app
```

Put a TLS terminator in front (or set Thruster `TLS_DOMAIN`) and keep the
same env contract.

## What this does not do

- It does not deploy Holodex hosted previews.
- It does not weaken `config.hosts`, canonical-domain pinning, or production
  storage readiness to make a first boot easier.
- An end-to-end `kamal deploy` against real infrastructure is not exercised
  in CI; the contract is the image, the env snapshot, and `/healthcheck`.
