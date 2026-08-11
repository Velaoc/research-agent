# Foundation modules

Generation is a one-way fork. A generated application never pulls foundation
updates. The foundation is a menu the generator picks from: modules that fit
are copied in; modules that do not are **absent** from the generated
repository, not merely disabled by a runtime flag.

This document is the design contract. The minimal mechanism that makes it
testable lives in `lib/foundation/modules/`, `config/foundation/modules/`,
and `bin/foundation-modules`.

## 1. What constitutes a module

A module is a named, omittable slice of the template. Anything the slice
owns must be listed in its manifest so omission can erase it completely.

Typical ownership:

| Kind | Examples |
|---|---|
| Models | `app/models/foundation/<module>/` |
| Migrations | `db/migrate/*_<module>*.rb` (and matching `schema.rb` tables) |
| Routes | Dedicated scopes/resources; root-route choice when applicable |
| Controllers / views / helpers / mailers / jobs / services | Under the module namespace, plus any admin surface dedicated to it |
| Seeds | Demo rows and seed entry points that reference module models |
| Config | `foundation.yml` keys, initializers, recurring jobs, readiness checks, deploy secret comments |
| Tests | Unit/integration/system coverage and fixtures owned by the module |
| Docs | Module-specific operator docs |
| Nav / UI entry points | Top app bar, adaptive nav, admin sidebar, dashboard cards, footer links |

**Not** a module: core accounts, organizations, billing/plans, admin shell,
MD3 components, reauthentication, native shell, host authorization, deploy
wiring. Those are assumed present (see section 5).

The existing storefront is the first declared module. It still uses the
legacy runtime flag `storefront_enabled` while the module is **included**
(default). Omission is a separate, generation-time concern.

## 2. How a module is declared

Each module has one manifest:

```
config/foundation/modules/<name>.yml
```

Required fields:

- `name` — stable token (`storefront`). Used in markers and CLI.
- `summary` — one-line description for generator menus.
- `default` — `included` or `omitted`. The foundation checkout default is
  that every shipped module is `included` so HEAD behaves as today.
- `paths` — files and directories owned exclusively by the module. Omission
  deletes them.
- `table_prefixes` — schema/migration table name prefixes (e.g.
  `storefront_`). Used to strip `db/schema.rb` and to residue-scan.
- `config_keys` — keys under `config/foundation.yml` `shared:` owned by the
  module.
- `residue_patterns` — regexes that must not match anywhere in the tree
  after omission (routes, constants, helpers, nav labels, seed references).

Optional:

- `depends_on` — other module names that must also be included. The omit
  tool refuses to leave a dependent without its dependency. Core is never
  listed here.
- `soft_references` — documented optional integrations with other modules
  or core (see section 4). Not enforced by deletion; they guide authors.

The registry loads every `*.yml` in that directory. No second registry,
no Ruby DSL required for declaration.

## 3. How omission works mechanically, and when it happens

**When.** Only at generation time (or an explicit operator run of the omit
tool on a checkout). Never at boot, never per-request. A running app does
not discover omitted modules.

**Default.** A foundation checkout with no omit step keeps every
`default: included` module on disk. Runtime flags such as
`storefront_enabled` continue to work exactly as today.

**Mechanism.** `bin/foundation-modules omit <name> --root <path>`:

1. Loads the manifest.
2. Deletes every owned path (files and directory trees).
3. Deletes the manifest itself.
4. Strips host-file contributions delimited by markers (below).
5. Removes owned `config_keys` from `config/foundation.yml`.
6. Removes `db/schema.rb` `create_table` / `add_foreign_key` rows whose
   names match `table_prefixes`.
7. Runs a residue scan (`residue_patterns` + marker leftovers). Non-zero
   exit if anything remains.

Omission is plain filesystem surgery. It is fully reversible from git
(`git checkout -- .` or restoring the pre-omit commit). No migration
path between foundation releases is required or provided.

### Host-file markers

Module-owned files are deleted wholesale. Contributions that must live
inside core files are wrapped so the omit tool can excise them without
hand-written per-file patches.

**Block removal** (Ruby, YAML, and other hash-comment languages) — wrap with
lines that read `foundation:module NAME` and `/foundation:module NAME`
after a `#`:

```
# foundation:module storefront
has_many :storefront_orders, class_name: "Foundation::Storefront::Order"
# /foundation:module storefront
```

**Block removal** (ERB) — same tokens inside ERB comments:

```
<%# foundation:module storefront %>
  ...storefront-only markup...
<%# /foundation:module storefront %>
```

**Choose collapse** — when the core needs a different branch after omit.
Tag the `if` / `else` / `end` lines with `foundation:module NAME`. The omit
tool keeps the else body only:

```
<% if Foundation.storefront_enabled? # foundation:module storefront %>
  <%= link_to "Shop", storefront_products_path %>
<% else # foundation:module storefront %>
  <%= link_to "Pricing", pricing_path %>
<% end # foundation:module storefront %>
```

After omit that becomes only the Pricing link. While the module remains
included, the tags are ordinary comments and the runtime flag still
decides the branch.

Markers must not change default behaviour. They are comments only until
an omit run rewrites the file.

## 4. How two modules relate without depending on each other

Hard module-to-module `belongs_to` / foreign keys create an implicit
dependency: omitting CRM would break Scheduling’s `appointment.contact`
association and migration.

**Rule: no foreign keys between omittable modules.** Cross-module links
use one of:

1. **Soft reference columns on the referencing side** — nullable
   `contact_ref` string (stable public id) or `contact_id` bigint **without**
   a database foreign key and **without** a `belongs_to` that points at a
   possibly-absent constant. The referencing module resolves the record
   only when the other module’s constant is defined:

   ```
   def contact
     return unless Foundation.module_available?("crm")
     Foundation::Crm::Contact.find_by(id: contact_id)
   end
   ```

2. **Core as the join hub** — both modules optionally point at a core
   model (User, Organization). That is a dependency on core, which every
   app has, not on each other.

3. **Application-level composition after generation** — if a product needs
   a real FK between two included modules, the application adds it in its
   own migration after the fork. The foundation never ships that FK.

`Foundation.module_available?` is true when the module’s manifest still
exists on disk (or, after boot, when its registry entry loaded). Omitted
modules are absent from the registry because their manifest was deleted
with them.

Storefront today soft-links to core only (`orders.user_id` to users,
nullify). It does not depend on any other omittable module.

## 5. What a module may assume from the core

Always present:

- Rails 8.1 stack, PostgreSQL, Solid Queue/Cache/Cable
- `Foundation` namespace, `config/foundation.yml`, `Foundation::RuntimeConfig`
- Devise auth, legal assent, OAuth linking
- Organizations, roles, invitations, `Current.organization`
- Billing/plans (Pay) and pricing page
- Operator admin shell (Madmin) and audit helper
- Device sessions, step-up reauthentication
- MD3 tokens, ERB components, adaptive navigation shell
- Host authorization, healthcheck, mail, Active Storage
- Native shell server contract, deploy config

A module may:

- Add routes inside `config/routes.rb` (marked)
- Add nav items via marked regions in the shared layouts
- Register recurring jobs in `config/recurring.yml` (marked)
- Attach optional `has_many` associations onto core models (marked)
- Read `Foundation.runtime_config` and foundation identity keys
- Use MD3 partials and the admin audit helper

A module must not:

- Require another omittable module at boot
- Patch core behaviour invisibly without markers
- Ship secrets, proprietary names, or non-permissive gems
- Break M11 reauthentication, M14 native, host authorization, or deploy

## 6. Migrations and schema coherence

- Module migrations live in `db/migrate/` and are listed under `paths`.
- Omission deletes those files. A clean `bin/rails db:migrate` on an
  omitted tree never creates the module’s tables.
- The omit tool also strips matching tables and foreign keys from the
  committed `db/schema.rb` so `db:schema:load` matches migrate-from-scratch.
- Table names carry the module prefix (`storefront_*`) so residue scans
  and schema stripping stay mechanical.
- Cross-module FKs are forbidden in foundation migrations (section 4). FKs
  from a module table to **core** tables are allowed (`user_id`,
  `organization_id`) and disappear with the module migration.

No orphan table remains after omit + migrate because the creating
migration is gone and schema.rb was scrubbed.

## 7. NO-RESIDUE guarantee and how it is tested

After `omit <name>`, the tree must contain:

- no owned paths
- no marker delimiters for that name
- no `residue_patterns` matches under app/, config/, db/, lib/, test/
  (tooling under `lib/foundation/modules` and this design doc may still
  describe the module by name; the scan allowlists those paths)
- no `table_prefixes` tables in `db/schema.rb`
- no owned keys in `config/foundation.yml`
- no routes, nav labels, seeds, or jobs that reference deleted constants

The test suite for the mechanism:

1. Copies the template into a temporary root (excluding `.git`, `tmp`,
   `log`, storage artifacts).
2. Runs `bin/foundation-modules omit storefront --root <copy>`.
3. Asserts the residue scan is clean (CLI exit 0 and explicit assertions).
4. Asserts owned paths and storefront migrations/tables are gone.
5. Asserts host files no longer reference `Foundation::Storefront` or
   storefront route helpers.
6. Loads the omitter’s result for seeds/routes/nav and checks the
   storefront demo seed path is gone.

**Default configuration** (no omit) remains the normal `bin/rails test`
gate: behaviour identical to pre-module-composition HEAD.

### Deferred (explicitly not in the minimal mechanism)

- Generator UI that presents the module menu (host-side create app flow).
- Converting storefront’s runtime flag into “included always on” after
  a future cleanup; the flag stays while the module is included.
- Physically running the full Rails suite inside the omitted copy in CI
  (boot + migrate + test). The residue test proves structural absence;
  full omitted-app CI is a follow-up once more modules exist.
- Automatic marker discovery; authors must wrap host contributions.
- Packwerk/engines packaging; modules are plain trees + manifests.
