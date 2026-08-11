# frozen_string_literal: true

MissionControl::Jobs.base_controller_class = "Foundation::Admin::BaseController"
MissionControl::Jobs.http_basic_auth_enabled = false

Rails.application.config.to_prepare do
  MissionControl::Jobs::JobsHelper.prepend(Foundation::Admin::MissionControlJobsHelper) unless
    MissionControl::Jobs::JobsHelper < Foundation::Admin::MissionControlJobsHelper
end
