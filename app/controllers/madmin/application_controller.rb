# frozen_string_literal: true

module Madmin
  class ApplicationController < Madmin::BaseController
    include Rails.application.routes.url_helpers
    include Foundation::AdminAccess
    include Foundation::Reauthentication

    helper ApplicationHelper
    helper Foundation::MaterialHelper
    helper Foundation::MetaHelper
  end
end
