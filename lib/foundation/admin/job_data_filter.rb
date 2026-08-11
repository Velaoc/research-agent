# frozen_string_literal: true

module Foundation
  module Admin
    module JobDataFilter
      FILTERED = "[FILTERED]"

      module_function

      # A positional job argument has no trustworthy key from which to infer
      # sensitivity, so scalar/array values are hidden. Hash arguments retain
      # operationally useful non-sensitive keys while Rails' configured
      # parameter filter redacts matching values recursively.
      def arguments(serialized_arguments)
        Array(serialized_arguments).map do |argument|
          argument.is_a?(Hash) ? parameter_filter.filter(argument.deep_dup) : FILTERED
        end
      end

      def raw_data(data)
        filtered = parameter_filter.filter(data.deep_dup)
        return filtered unless filtered.is_a?(Hash)

        key = filtered.key?("arguments") ? "arguments" : :arguments
        filtered[key] = arguments(data[key]) if data.key?(key)
        filtered
      end

      def parameter_filter
        ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      end
    end
  end
end
