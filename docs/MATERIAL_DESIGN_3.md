# Material Design 3 in Vela Foundation

This project implements a small, original Rails-native design system from the
public [Material Design 3 specification](https://m3.material.io/). It is not a
JavaScript component kit. HTML stays in ERB, interaction stays in focused
Stimulus controllers, and production serves only local CSS, JavaScript, and
font assets.

## Tokens and theming

`config/foundation.yml` contains one `brand_seed_color`. The deterministic
generator in `tools/material/generate_tokens.mjs` passes that seed to
`SchemeTonalSpot` from `@material/material-color-utilities` 0.4.0 with the
documented 2021 variant and contrast level 0. It writes:

- `config/material_tokens.json`, the reviewable light and dark source of truth;
- `app/assets/stylesheets/material_tokens.css`, semantic CSS custom properties;
- `app/assets/stylesheets/material_system.css`, typography, shape, elevation,
  state, component, and layout rules.

Production does not install Node or contact a CDN. The generated files are
committed. Tailwind v4 exposes semantic utilities such as `bg-md-primary`,
`text-md-on-primary`, `bg-md-surface`, and `text-md-on-surface`.

To change the brand seed, edit the six-digit hex value and regenerate. The
normal development path rebuilds the reviewed generator bundle first:

```sh
cd tools/material
npm ci
npm run generate:tokens
cd ../..
bin/rails tailwindcss:build
bin/rails test test/models/material_design_tokens_test.rb
```

For an offline rename environment that already supplies Node but has no npm
installation or network access, use the committed self-contained bundle:

```sh
node tools/material/dist/generate_tokens.mjs
node tools/material/dist/generate_tokens.mjs --check
```

`npm test` rebuilds the bundle from the pinned package source, compares it
byte-for-byte with the committed bundle, and then checks the committed token
outputs. Production never executes this tooling.

Review both schemes after a seed change. Tests enforce the generator/version
contract, the generated `config/material_tokens.sha256` manifest, matching role
sets, and WCAG AA contrast for semantic foreground/background pairs. The
generator updates the manifest together with the artifacts, so re-seeding a
cloned application never requires editing test source.

The theme controller begins with `prefers-color-scheme`. The top-bar control
cycles system, light, and dark. It stores only the string preference in local
storage under `foundation.color-theme`; it sends nothing over the network and
does not identify a person.

## Material Symbols

`material_symbol(:home)` renders a private-use codepoint from the local
Material Symbols Rounded subset. Decorative symbols get `aria-hidden`; pass
`label:` only when the symbol itself needs an accessible name.

```erb
<%= material_symbol(:settings) %>
<%= material_symbol(:warning, size: 28, fill: true, label: "Warning") %>
```

Only names in `Foundation::MaterialHelper::MATERIAL_SYMBOLS` are accepted.
`tools/material/symbols.txt` records the same pinned codepoint map. To change
the inventory, update both maps, then run `tools/material/generate_symbols.sh`.
The script downloads the official font, codepoint index, and Apache license
from the pinned Google revision; verifies their SHA-256 values; and creates a
small WOFF2 containing only those codepoints. Never add a runtime font URL.

## Components

The component partials are under `app/views/foundation/components`; helper
entry points are in `Foundation::MaterialHelper`.

| Component | Entry point or partial | Important states |
|---|---|---|
| Buttons | `md_button` | filled, tonal, outlined, text, elevated, disabled, loading |
| Icon button | `md_icon_button` | label required, selected, disabled |
| Text field | `md_text_field` | label, hint, Rails validation error |
| Select | `md_select` | label, hint, Rails validation error |
| Choices | `md_choice` | checkbox, radio, switch |
| Card | `md_card` | elevated, filled, outlined |
| Chip | `md_chip` | selected, removable |
| Dialog | `_dialog` | native `dialog`, modal close, backdrop close |
| Menu | `_menu` | keyboard traversal, Escape, outside click |
| Tabs | `_tabs` | current state, arrow/Home/End navigation |
| Snackbar | `_snackbar` | status/alert, dismiss, reduced-motion behavior |
| Progress | `md_progress` | indeterminate or numeric value |
| Tooltip | `md_tooltip` | hover and keyboard focus |
| App chrome | `_top_app_bar`, `_adaptive_navigation` | public/authenticated and responsive states |

Examples:

```erb
<%= md_button "Save", variant: :filled, loading: @saving %>
<%= md_icon_button :delete, label: "Delete project", disabled: !policy.delete? %>

<%= form_with model: @project do |form| %>
  <%= md_text_field form, :name, label: "Project name", hint: "Visible to your team" %>
  <%= md_select form, :visibility, [["Team", "team"], ["Private", "private"]], label: "Visibility" %>
  <%= md_choice form, :notifications, type: :switch, label: "Email notifications" %>
<% end %>

<%= md_card variant: :outlined do %>
  <h2>Quarterly planning</h2>
  <p>Bring decisions and follow-up work together.</p>
<% end %>

<%= md_dialog id: "archive-dialog", title: "Archive project?", trigger_label: "Archive" do %>
  The project will leave the active workspace. You can restore it later.
<% end %>
```

Helpers and Rails tags escape labels, content, validation messages, and
attributes. Do not pass `html_safe` user content. There are no inline event
handlers; interactions use `data-action` and `foundation--*` controllers.

## Adaptive layout

The CSS window classes are exact and mobile-first:

| Class | Width | Navigation |
|---|---:|---|
| Compact | below 600px | bottom navigation |
| Medium | 600–839px | navigation rail |
| Expanded | 840–1199px | rail; list-detail and supporting panes may split |
| Large | 1200–1599px | navigation drawer |
| Extra-large | 1600px and above | wider drawer and content gutters |

Use `.md-list-detail` when the primary and detail panes are peers, and
`.md-supporting-pane` for secondary context. They remain one column until
expanded, so the compact view reflows rather than horizontally scrolling.
Avoid page-level fixed widths. Constrain long content with `min()`, `max-width`,
and `minmax(0, 1fr)`.

The spacing rhythm uses multiples of 8px, with 4px reserved for fine internal
alignment. Interactive controls have at least a 48 by 48 CSS-pixel target.

## Accessibility checklist

- Keep the skip link, header/nav/main/footer landmarks, and one clear page
  heading.
- Give every input a concise visible label; associate hints and validation
  errors with `aria-describedby`.
- Give icon-only buttons a label. Decorative symbols stay hidden from the
  accessibility tree.
- Preserve `:focus-visible`. Never remove outlines without a visible replacement.
- Prefer native buttons, links, inputs, `details`, and `dialog` semantics.
- Check keyboard use: Tab/Shift+Tab, Enter/Space, Escape, arrow keys for menus
  and tabs, plus outside-click dismissal where appropriate.
- Test both generated schemes, forced colors, 200% zoom, a 320px viewport, and
  reduced motion. Motion is supplementary and collapses under
  `prefers-reduced-motion`.
- Keep compact content reflowing. Data tables may scroll inside their labelled
  table container; the page itself must not gain horizontal overflow.

The upstream artifacts and exact licenses are recorded in
`THIRD_PARTY_NOTICES.md`.
