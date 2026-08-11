# frozen_string_literal: true

require "yaml"

module Foundation
  module Modules
    class Manifest
      class Error < StandardError; end

      ATTRS = %i[
        name summary default paths table_prefixes config_keys residue_patterns
        depends_on soft_references source_path
      ].freeze

      attr_reader(*ATTRS)

      def initialize(attributes)
        ATTRS.each do |key|
          instance_variable_set(:"@#{key}", attributes[key])
        end
        freeze
      end

      def self.load_file(path)
        raw = YAML.safe_load(File.read(path, encoding: "UTF-8"), permitted_classes: [], aliases: false)
        raise Error, "#{path}: expected a mapping" unless raw.is_a?(Hash)

        name = raw["name"].to_s
        raise Error, "#{path}: name is required" if name.empty?
        raise Error, "#{path}: name must match the file basename" unless File.basename(path, ".yml") == name

        default = raw.fetch("default", "included").to_s
        raise Error, "#{path}: default must be included or omitted" unless %w[included omitted].include?(default)

        paths = Array(raw["paths"]).map(&:to_s)
        raise Error, "#{path}: paths must be a non-empty list" if paths.empty?

        new(
          name: name,
          summary: raw["summary"].to_s,
          default: default,
          paths: paths.freeze,
          table_prefixes: Array(raw["table_prefixes"]).map(&:to_s).freeze,
          config_keys: Array(raw["config_keys"]).map(&:to_s).freeze,
          residue_patterns: Array(raw["residue_patterns"]).map(&:to_s).freeze,
          depends_on: Array(raw["depends_on"]).map(&:to_s).freeze,
          soft_references: Array(raw["soft_references"]).map(&:to_s).freeze,
          source_path: path.to_s
        )
      end

      def included_by_default?
        default == "included"
      end
    end
  end
end
