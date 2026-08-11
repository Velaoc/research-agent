# frozen_string_literal: true

module Foundation
  module Crm
    class BaseController < ApplicationController
      before_action :authenticate_user!
      before_action :require_organization!

      helper Foundation::CrmHelper

      private

      def require_organization!
        @organization = current_organization
        return if @organization

        redirect_to organizations.organizations_path, alert: "Choose an organization first."
      end

      def crm_scope(model)
        model.for_organization(@organization)
      end

      def find_crm!(model, id = params[:id])
        crm_scope(model).find(id)
      end

      def organization_members
        @organization.users.order(:email)
      end

      def ensure_default_pipeline!
        @pipeline = Pipeline.ensure_default!(@organization)
      end

      def record_created(record)
        ActivityRecorder.record!(
          organization: @organization,
          actor: current_user,
          trackable: record,
          kind: "created",
          summary: "#{record.class.name.demodulize} created: #{record.try(:display_name) || record.id}"
        )
      end

      def pagination_page
        Integer(params.fetch(:page, 1), 10, exception: false).to_i.clamp(1, 1_000)
      end

      def paginate(scope, per_page: 25)
        @page = pagination_page
        rows = scope.offset((@page - 1) * per_page).limit(per_page + 1).to_a
        @has_next_page = rows.length > per_page
        rows.first(per_page)
      end
    end
  end
end
