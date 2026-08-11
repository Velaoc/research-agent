# frozen_string_literal: true

module Foundation
  module Admin
    module Audit
      EVENT_NAME = "foundation.admin.mutation"

      module_function

      def write(action:, actor:, request:, subject:, outcome:, error_class: nil, details: nil)
        entry = {
          event: EVENT_NAME,
          action: action,
          actor_id: actor&.id,
          request_id: request.request_id,
          request_method: request.request_method,
          subject_type: subject[:type],
          subject_id: subject[:id],
          outcome: outcome,
          error_class: error_class,
          details: details
        }.compact

        Rails.logger.info(entry.to_json)
      end
    end
  end
end
