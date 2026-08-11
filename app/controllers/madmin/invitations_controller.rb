# frozen_string_literal: true

module Madmin
  class InvitationsController < Madmin::ResourceController
    private

    def scoped_resources
      super.preload(:organization, :invited_by)
    end
  end
end
