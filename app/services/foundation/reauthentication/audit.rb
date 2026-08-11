# frozen_string_literal: true

module Foundation
  module Reauthentication
    module Audit
      EVENT_NAME = "foundation.reauthentication"

      module_function

      def write(outcome:, actor:, request:, details: nil)
        entry = {
          event: EVENT_NAME,
          actor_id: actor&.id,
          request_id: request.request_id,
          request_method: request.request_method,
          outcome: outcome.to_s,
          details: details
        }.compact

        Rails.logger.info(entry.to_json)
      end
    end
  end
end
