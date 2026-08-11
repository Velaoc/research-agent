# frozen_string_literal: true

module Foundation
  module Crm
    class ActivityRecorder
      def self.record!(organization:, trackable:, kind:, summary:, actor: nil, metadata: {})
        Activity.create!(
          organization: organization,
          actor: actor,
          trackable: trackable,
          kind: kind,
          summary: summary,
          metadata: metadata || {}
        )
      end
    end
  end
end
