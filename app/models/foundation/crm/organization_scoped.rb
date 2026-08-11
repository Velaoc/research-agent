# frozen_string_literal: true

module Foundation
  module Crm
    # Every CRM row is owned by exactly one organization. Controllers must
    # load records through for_organization so cross-tenant ids are
    # indistinguishable from missing rows (RecordNotFound → 404).
    module OrganizationScoped
      extend ActiveSupport::Concern

      included do
        belongs_to :organization, class_name: "Organizations::Organization"

        scope :for_organization, ->(organization) {
          where(organization_id: organization.is_a?(Integer) ? organization : organization.id)
        }
      end
    end
  end
end
