# frozen_string_literal: true

require_relative "manifest"

module Foundation
  module Modules
    class Registry
      def initialize(root)
        @root = File.expand_path(root)
        @manifests = load_manifests
      end

      attr_reader :root

      def all
        @manifests.values.sort_by(&:name)
      end

      def fetch(name)
        @manifests.fetch(name.to_s) do
          raise Manifest::Error, "unknown module #{name.inspect} (known: #{@manifests.keys.sort.join(', ')})"
        end
      end

      def available?(name)
        @manifests.key?(name.to_s)
      end

      def directory
        File.join(@root, "config", "foundation", "modules")
      end

      private

      def load_manifests
        dir = directory
        return {} unless File.directory?(dir)

        Dir.children(dir).sort.each_with_object({}) do |entry, acc|
          next unless entry.end_with?(".yml")

          path = File.join(dir, entry)
          manifest = Manifest.load_file(path)
          acc[manifest.name] = manifest
        end
      end
    end
  end
end
