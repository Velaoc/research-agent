# frozen_string_literal: true

module Madmin
  class SessionEventsController < Madmin::ResourceController
    EVENT_RESOURCE_NAME = "SessionEventResource"

    private

    def resource_name = EVENT_RESOURCE_NAME

    def scoped_resources
      super.includes(:authenticatable)
    end
  end
end
