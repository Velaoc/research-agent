# frozen_string_literal: true

module Foundation
  module Admin
    class BaseController < ApplicationController
      include Foundation::AdminAccess
    end
  end
end
