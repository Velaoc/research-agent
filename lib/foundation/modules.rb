# frozen_string_literal: true

require_relative "modules/manifest"
require_relative "modules/registry"
require_relative "modules/omit"

module Foundation
  module Modules
    def self.registry(root: Dir.pwd)
      Registry.new(root)
    end

    def self.available?(name, root: Dir.pwd)
      Registry.new(root).available?(name)
    end

    def self.omit!(name, root: Dir.pwd)
      Omit.new(root: root, name: name).call
    end
  end
end
