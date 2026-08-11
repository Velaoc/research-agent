# Native mobile shell — server contract

This document is the server half of a Hotwire Native shell. It is written from
public specifications only:

- Hotwire Native path configuration and bridge overview
  (`https://native.hotwired.dev/`)
- Apple Universal Links / `apple-app-site-association`
- Google Digital Asset Links / Android App Links (`assetlinks.json`)
- Rails 8.1, Devise, and turbo-rails (`hotwire_native_app?`)

It does not describe any third-party application template.

## Detection

Every native-only behaviour is gated on the request User-Agent matching
turbo-rails' `hotwire_native_app?` contract:

```text
/(Turbo|Hotwire) Native/
```

Ordinary browsers receive **404** for native-only routes. They never receive
an alternate document, a redirect into the native flow, or a softer error.
Association files are the sole exception: OS verifiers are ordinary HTTPS
clients, so those paths stay public.

## Endpoints

| Method | Path | Audience | Purpose |
|--------|------|----------|---------|
| GET | `/native/configurations/ios/v1` | Native shell | iOS path configuration (JSON) |
| GET | `/native/configurations/android/v1` | Native shell | Android path configuration (JSON) |
| GET | `/native/entry` | Native shell | Launch handoff |
| GET | `/native/auth` | Native shell | Native sign-in landing (HTML) |
| GET | `/native/session` | Native shell | Current-user poll (JSON) |
| GET | `/.well-known/apple-app-site-association` | Public | Apple Universal Links |
| GET | `/apple-app-site-association` | Public | Same document (Apple allows root) |
| GET | `/.well-known/assetlinks.json` | Public | Android App Links |

Path configuration is **versioned in the URL**. A shipped binary pins
`/v1`; a future breaking change publishes `/v2` and leaves `/v1` intact.
Unknown versions and platforms 404.

The PWA manifest at `/manifest.webmanifest` is unchanged. Native and PWA
coexist.

## Path configuration shape

Documents follow the public Hotwire Native schema:

```json
{
  "settings": { "screenshots_enabled": true, "registration_enabled": true },
  "rules": [
    {
      "patterns": [".*"],
      "properties": { "context": "default", "pull_to_refresh_enabled": true }
    }
  ]
}
```

v1 rules open auth, password, confirmation, OAuth assent, and step-up
reauthentication paths as modals without pull-to-refresh. Android rules
include the stock Hotwire web-fragment `uri` / `fallback_uri` properties from
the public Android reference.

## Entry and auth handoff

1. Shell opens `/native/entry` at launch (or after a cold start).
2. Guest → redirect to `/native/auth` (MD3 sign-in landing, Material Symbols
   only, no emoji).
3. Sign-in posts to the normal Devise session path (or OmniAuth). Native
   shells are sent back to `/native/entry` via `after_sign_in_path_for`.
4. Signed-in entry uses turbo-rails `recede_or_redirect_to`, which issues the
   historical `recede` location the shell intercepts to dismiss its auth
   stack; browsers never reach this action.

Step-up reauthentication (M11) is unchanged. Native UAs still hit the same
`require_recent_reauthentication!` gate before billing portal, identity
unlink, credential change, organization deletion, and session revocation.
There is no native shortcut around the trust window.

## Current-user poll

`GET /native/session` returns:

```json
{ "signed_in": false, "user": null }
```

or

```json
{ "signed_in": true, "user": { "id": 1, "email": "user@example.com" } }
```

It does not create, extend, or destroy a session. Cache headers are
`Cache-Control: no-cache`.

## Durable sign-in and cookies

Native web views do not share the system browser cookie jar. Persistence
relies on cookies the **in-app WebView** stores:

| Cookie | Role | Lifetime |
|--------|------|----------|
| Session cookie (`_session_id` or the app's key) | Rails/Devise signed session | Browser/WebView process; `force_ssl` → `Secure` in production |
| `remember_user_token` | Devise `:rememberable` | Default `Devise.remember_for` (2 weeks) |

What this server does:

1. On password sign-in from a native UA, `Users::SessionsController` forces
   `remember_me=1` so Devise always writes `remember_user_token`.
2. On OAuth identity sign-in from a native UA, the OmniAuth callback calls
   `remember_me(user)` for the same cookie.
3. Sign-out still runs `expire_all_remember_me_on_sign_out` (Devise default
   here), clearing remember cookies everywhere.
4. Production enables `config.force_ssl = true`, so cookies are marked
   `Secure`. Rails' default `SameSite=Lax` applies.

What the shell operator must configure (not enforced server-side):

- **iOS (`WKWebView`)**: use a single shared `WKProcessPool` (or the Hotwire
  Native default web-view configuration) so successive screens see the same
  cookie store. Do not reset website data between navigations.
- **Android (`WebView`)**: accept third-party cookies only if you embed
  cross-site content (this app does not require that). Persist cookies via
  `CookieManager.getInstance().setAcceptCookie(true)` and flush on background.
- Both platforms must load the product origin over **HTTPS** in release
  builds so `Secure` cookies are stored.

The server does **not** issue a custom native token, JWT, or header-based
session. The web view cookie jar is the session.

## Association files

Identifiers come only from `config/foundation.yml` → `native`:

```yaml
native:
  ios_app_id: "TEAMID.com.example.app"
  ios_paths: ["*"]
  android_package_name: "com.example.app"
  android_sha256_cert_fingerprints:
    - "AA:BB:..."
```

| State | Behaviour |
|-------|-----------|
| `ios_app_id` blank | `apple-app-site-association` → **404** |
| Android package or fingerprints blank | `assetlinks.json` → **404** |
| Configured | JSON with `Content-Type: application/json` |

404 is intentional: Apple and Google treat a missing file as “no
association,” which is safe. A placeholder Team ID or package name would be
worse than absence.

Host authorization is not bypassed for these paths. They are served on the
product domain already allowed by `config.hosts` (see
`Foundation::RuntimeConfig#allowed_request_hosts`).

## Operator checklist (device)

Server tests cannot drive a real shell. Before shipping a binary, verify:

1. Shell fetches `/native/configurations/{ios\|android}/v1` at launch and
   applies rules (modal auth, pull-to-refresh).
2. Cold start → `/native/entry` → auth → recede returns to the main stack.
3. Kill and relaunch within `remember_for`: `/native/session` reports
   `signed_in: true` without re-prompting.
4. Sign-out clears the session; relaunch shows the auth landing.
5. A gated action (billing portal) still presents step-up reauthentication.
6. With association identifiers configured and HTTPS on the product domain,
   iOS Universal Links and Android App Links open the shell (Apple CDN and
   Google’s statement list crawler cache aggressively — allow time / use
   their re-verification tools).
7. Installing the PWA from Safari/Chrome is unaffected.
