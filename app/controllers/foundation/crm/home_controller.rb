# frozen_string_literal: true

module Foundation
  module Crm
    class HomeController < BaseController
      def show
        ensure_default_pipeline!
        @contacts_count = crm_scope(Contact).count
        @companies_count = crm_scope(Company).count
        @leads_count = crm_scope(Lead).where.not(status: %w[converted disqualified]).count
        @open_opportunities_count = crm_scope(Opportunity).where(status: "open").count
        @open_tasks = crm_scope(Task).open_tasks.ordered.limit(8)
        @recent_activities = crm_scope(Activity).ordered.limit(12)
      end
    end
  end
end
