# frozen_string_literal: true

namespace :foundation do
  desc "Regenerate public/icon.svg from brand_seed_color in config/foundation.yml"
  task icon: :environment do
    seed = Rails.configuration.x.foundation[:brand_seed_color]
    path = Rails.root.join(Foundation::AppIcon::PATH)
    path.write(Foundation::AppIcon.svg(seed))

    puts "Wrote #{Foundation::AppIcon::PATH} from brand_seed_color #{Foundation::AppIcon.normalize_color(seed)}."
  end
end
