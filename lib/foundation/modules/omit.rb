# frozen_string_literal: true

require "fileutils"
require "yaml"
require_relative "registry"

module Foundation
  module Modules
    # Generation-time filesystem surgery: delete a module's owned paths and
    # strip its host-file contributions. Plain Ruby — no Rails boot.
    class Omit
      class Error < StandardError; end

      RESULT = Struct.new(:removed_paths, :rewritten_files, :residue, keyword_init: true)

      # Paths that may still mention a module by name after omit (design, tooling,
      # product narrative). Code under app/config/db/test must still be clean.
      ALLOWLIST_PREFIXES = [
        "docs/",
        "README.md",
        "lib/foundation/modules/",
        "bin/foundation-modules",
        "test/lib/foundation/modules_test.rb",
        "PROVENANCE.md",
        "SPEC.md"
      ].freeze

      SCAN_ROOTS = %w[app bin config db docs lib script test].freeze

      def initialize(root:, name:)
        @root = File.expand_path(root)
        @registry = Registry.new(@root)
        @manifest = @registry.fetch(name)
      end

      def call
        assert_dependencies_ok!
        removed = delete_owned_paths
        removed.concat(delete_manifest)
        rewritten = []
        rewritten.concat(strip_markers_in_tree)
        rewritten.concat(strip_css_prefix_lines)
        rewritten.concat(strip_foundation_yml_keys)
        rewritten.concat(strip_schema_tables)
        residue = residue_hits
        raise Error, "residue remains after omitting #{@manifest.name}:\n#{residue.join("\n")}" if residue.any?

        RESULT.new(removed_paths: removed.uniq.sort, rewritten_files: rewritten.uniq.sort, residue: [])
      end

      def self.residue_for(root:, name:, patterns:)
        new(root: root, name: name).send(:scan_residue, patterns)
      end

      private

      def assert_dependencies_ok!
        dependents = @registry.all.select { |m| m.depends_on.include?(@manifest.name) }
        return if dependents.empty?

        raise Error,
          "cannot omit #{@manifest.name}: still required by #{dependents.map(&:name).sort.join(', ')}"
      end

      def delete_owned_paths
        @manifest.paths.filter_map do |relative|
          absolute = File.join(@root, relative)
          next unless File.exist?(absolute) || File.symlink?(absolute)

          FileUtils.rm_rf(absolute)
          relative
        end
      end

      def delete_manifest
        relative = "config/foundation/modules/#{@manifest.name}.yml"
        absolute = File.join(@root, relative)
        return [] unless File.file?(absolute)

        FileUtils.rm_f(absolute)
        [ relative ]
      end

      def strip_markers_in_tree
        rewritten = []
        each_text_file do |relative, absolute|
          next if allowlisted?(relative)

          original = File.read(absolute, encoding: "UTF-8")
          updated = strip_markers(original, @manifest.name)
          next if updated == original

          File.write(absolute, updated, encoding: "UTF-8")
          rewritten << relative
        end
        rewritten
      end

      def strip_markers(source, name)
        text = source.dup
        text = strip_comment_blocks(text, name)
        text = collapse_tagged_conditionals(text, name)
        text
      end

      # Block markers. Do not use the /x flag — "#" would start a regex comment.
      def strip_comment_blocks(text, name)
        n = Regexp.escape(name)
        erb = %r{^[ \t]*<%\#[ \t]*foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n.*?^[ \t]*<%\#[ \t]*/foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n?}m
        css = %r{^[ \t]*/\*[ \t]*foundation:module[ \t]+#{n}[ \t]*\*/[ \t]*\n.*?^[ \t]*/\*[ \t]*/foundation:module[ \t]+#{n}[ \t]*\*/[ \t]*\n?}m
        hash = %r{^[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*\n.*?^[ \t]*\#[ \t]*/foundation:module[ \t]+#{n}[ \t]*\n?}m
        text.gsub(erb, "").gsub(css, "").gsub(hash, "")
      end

      # Collapse if/else/end (Ruby or ERB) tagged with foundation:module NAME
      # into the else body only. No /x flag — see strip_comment_blocks.
      def collapse_tagged_conditionals(text, name)
        n = Regexp.escape(name)
        erb = %r{^[ \t]*<%[ \t]*if\b[^%]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n.*?^[ \t]*<%[ \t]*else[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n(.*?)^[ \t]*<%[ \t]*end[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n?}m
        text = text.gsub(erb) { Regexp.last_match(1) }

        erb_if = %r{^[ \t]*<%[ \t]*if\b[^%]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n.*?^[ \t]*<%[ \t]*end[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*%>[ \t]*\n?}m
        text = text.gsub(erb_if, "")

        ruby = %r{^[ \t]*if\b.*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*\n.*?^[ \t]*else[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*\n(.*?)^[ \t]*end[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*\n?}m
        text = text.gsub(ruby) { Regexp.last_match(1) }

        ruby_if = %r{^[ \t]*if\b.*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*\n.*?^[ \t]*end[ \t]*\#[ \t]*foundation:module[ \t]+#{n}[ \t]*\n?}m
        text.gsub(ruby_if, "")
      end

      def strip_css_prefix_lines
        prefixes = @manifest.residue_patterns.grep(/\A\./)
        return [] if prefixes.empty?

        rewritten = []
        each_text_file do |relative, absolute|
          next unless relative.end_with?(".css")

          original = File.read(absolute, encoding: "UTF-8")
          updated = original.lines.reject { |line| prefixes.any? { |prefix| line.include?(prefix) } }.join
          next if updated == original

          File.write(absolute, updated, encoding: "UTF-8")
          rewritten << relative
        end
        rewritten
      end

      def strip_foundation_yml_keys
        relative = "config/foundation.yml"
        absolute = File.join(@root, relative)
        return [] unless File.file?(absolute)

        original = File.read(absolute, encoding: "UTF-8")
        updated = original.dup
        @manifest.config_keys.each do |key|
          updated.gsub!(/(?:^[ \t]*\#[^\n]*\n)*^[ \t]*#{Regexp.escape(key)}:[^\n]*\n(?:(?:^[ \t]*\#[^\n]*\n)|(?:^[ \t]+-[^\n]*\n))*/m, "")
        end
        updated.gsub!(/\n{3,}/, "\n\n")
        return [] if updated == original

        File.write(absolute, updated, encoding: "UTF-8")
        [ relative ]
      end

      def strip_schema_tables
        relative = "db/schema.rb"
        absolute = File.join(@root, relative)
        return [] unless File.file?(absolute)
        return [] if @manifest.table_prefixes.empty?

        original = File.read(absolute, encoding: "UTF-8")
        updated = original.dup
        @manifest.table_prefixes.each do |prefix|
          p = Regexp.escape(prefix)
          updated.gsub!(/^  create_table "#{p}[^"]*", force: :cascade do \|t\|.*?^  end\n+/m, "")
          updated.gsub!(/^  add_foreign_key "#{p}[^"]*".*\n/, "")
          updated.gsub!(/^  add_foreign_key "[^"]*", "#{p}[^"]*".*\n/, "")
        end
        return [] if updated == original

        File.write(absolute, updated, encoding: "UTF-8")
        [ relative ]
      end

      def residue_hits
        scan_residue(@manifest.residue_patterns)
      end

      def scan_residue(patterns)
        hits = []
        compiled = patterns.map { |p| [ p, Regexp.new(Regexp.escape(p)) ] }
        marker = /foundation:module[ \t]+#{Regexp.escape(@manifest.name)}\b/

        each_text_file do |relative, absolute|
          next if allowlisted?(relative)

          content = File.read(absolute, encoding: "UTF-8")
          if marker.match?(content)
            hits << "#{relative}: leftover module marker"
          end
          compiled.each do |label, regex|
            next unless regex.match?(content)

            hits << "#{relative}: matches #{label.inspect}"
          end
        end
        hits
      end

      def allowlisted?(relative)
        ALLOWLIST_PREFIXES.any? { |prefix| relative == prefix || relative.start_with?(prefix) }
      end

      def each_text_file
        SCAN_ROOTS.each do |top|
          base = File.join(@root, top)
          next unless File.directory?(base)

          Dir.glob(File.join(base, "**", "*"), File::FNM_DOTMATCH).each do |absolute|
            next unless File.file?(absolute)
            next if File.basename(absolute).start_with?(".")
            next if binary?(absolute)

            relative = absolute.delete_prefix(@root + File::SEPARATOR)
            yield relative, absolute
          end
        end
      end

      def binary?(path)
        return true if path.end_with?(".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".woff", ".woff2", ".ttf", ".otf", ".zip", ".gz")

        sample = File.read(path, 512, mode: "rb")
        sample&.include?("\x00")
      rescue Errno::ENOENT
        true
      end
    end
  end
end
