# frozen_string_literal: true

module Foundation
  module Admin
    module MissionControlJobsHelper
      def job_arguments(job)
        Foundation::Admin::JobDataFilter.arguments(job.serialized_arguments).map(&:to_s).join(", ")
      end

      def foundation_filtered_job_data(data)
        Foundation::Admin::JobDataFilter.raw_data(data)
      end
    end
  end
end
