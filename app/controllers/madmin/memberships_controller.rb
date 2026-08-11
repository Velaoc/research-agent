# frozen_string_literal: true

module Madmin
  class MembershipsController < Madmin::ResourceController
    private

    def scoped_resources
      super.preload(:organization, :user, :invited_by)
    end
  end
end
