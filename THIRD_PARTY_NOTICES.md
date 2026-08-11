# Third-party notices

Vela Foundation includes generated artifacts from the following public,
open-source projects. They are not required at application runtime except for
the committed local font subset.

## Material Color Utilities

- Project: `material-foundation/material-color-utilities`
- Package: `@material/material-color-utilities` 0.4.0
- Use: deterministic build-time generation of committed light and dark color tokens
- License: Apache License 2.0
- Package integrity: `sha512-dlq6VExJReb8dhjj3a/yTigr3ncNwoFmL5Iy2ENtbDX03EmNeOEdZ+vsaGrj7RTuO+mB7L58II4LCsl4NpM8uw==`

## Material Symbols Rounded

- Project: `google/material-design-icons`
- Revision: `50f0603134ce7b70b2d71b686cc13e8b57ccb74c`
- Use: a WOFF2 subset containing only the named PUA codepoints listed in `tools/material/symbols.txt`; helpers render those mapped codepoints rather than retaining the full ligature table
- Source font SHA-256: `3500043e8929d5140f34dff8f8687e1dd5fda3a33fff20bfcc96ecd0b2f99518`
- License: Apache License 2.0

The exact package license is preserved at
`vendor/licenses/material-color-utilities-APACHE-2.0.txt`. The exact icon
repository license is preserved separately at
`vendor/licenses/google-material-design-icons-APACHE-2.0.txt`.

## esbuild

- Project: `evanw/esbuild`
- Package: `esbuild` 0.25.8
- Use: build-time creation of the reviewed self-contained token-generator bundle
- License: MIT

The license text is preserved at `vendor/licenses/esbuild-MIT.txt`. esbuild is
not part of the application runtime or the generated token bundle.

## Ruby CSV

- Project: `ruby/csv`
- Gem: `csv` 3.3.6
- Use: strict, bounded parsing for the operator product importer
- License: Ruby License or BSD-2-Clause

The bundled BSD-2-Clause text is preserved at
`vendor/licenses/csv-BSD-2-Clause.txt`.
