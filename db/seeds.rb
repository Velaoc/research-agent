# Seeds are optional: this application boots, migrates, and serves every page
# with a completely empty database, and nothing here is required in
# production.
#
# The first operator account is promoted from the console on purpose; there is
# deliberately no seeded administrator, password, or API key anywhere in this
# repository.
# foundation:module storefront
# `bin/rails db:seed` only adds the storefront demo catalog, and only in
# development or a hosted preview (SPEC M10.3) — see lib/foundation/demo_seeds.rb.
Foundation::DemoSeeds.run!
# /foundation:module storefront
