# frozen_string_literal: true

require "shellwords"

module Foundation
  # Cheap, never-raising host capacity figures for health probes.
  # Returns nil when the platform does not expose a reliable figure so callers
  # can degrade to a passing informational check instead of crashing /healthcheck.
  module HostResources
    module_function

    def disk_usage_percent(path: "/")
      output = `df -Pk #{Shellwords.escape(path)} 2>/dev/null`
      return nil if output.blank?

      line = output.lines.drop(1).first
      return nil if line.blank?

      # df -Pk: Filesystem 1024-blocks Used Available Capacity Mounted
      capacity = line.split[4].to_s.delete_suffix("%")
      return nil unless capacity.match?(/\A\d+\z/)

      capacity.to_i
    rescue StandardError
      nil
    end

    def memory_usage_percent
      cgroup_memory_usage_percent || linux_meminfo_usage_percent || darwin_memory_usage_percent
    rescue StandardError
      nil
    end

    def cgroup_memory_usage_percent
      current_path = first_existing(
        "/sys/fs/cgroup/memory.current",
        "/sys/fs/cgroup/memory/memory.usage_in_bytes"
      )
      max_path = first_existing(
        "/sys/fs/cgroup/memory.max",
        "/sys/fs/cgroup/memory/memory.limit_in_bytes"
      )
      return nil unless current_path && max_path

      current = Integer(File.read(current_path).strip, exception: false)
      max = File.read(max_path).strip
      return nil if current.nil?
      return nil if max == "max"

      max_bytes = Integer(max, exception: false)
      return nil if max_bytes.nil? || max_bytes <= 0
      # Ignore unrealistically huge cgroup v1 "no limit" sentinels.
      return nil if max_bytes >= (1 << 62)

      ((current.to_f / max_bytes) * 100).round
    end
    module_function :cgroup_memory_usage_percent

    def linux_meminfo_usage_percent
      path = "/proc/meminfo"
      return nil unless File.readable?(path)

      info = File.read(path)
      total = meminfo_kb(info, "MemTotal")
      available = meminfo_kb(info, "MemAvailable")
      return nil if total.nil? || total <= 0 || available.nil?

      used = total - available
      ((used.to_f / total) * 100).round
    end
    module_function :linux_meminfo_usage_percent

    def darwin_memory_usage_percent
      return nil unless RUBY_PLATFORM.include?("darwin")

      total = `sysctl -n hw.memsize 2>/dev/null`.to_i
      return nil if total <= 0

      vm = `vm_stat 2>/dev/null`
      return nil if vm.blank?

      page_size = vm[/page size of (\d+) bytes/, 1]&.to_i
      page_size = 4096 if page_size.nil? || page_size <= 0
      free_pages = vm_stat_pages(vm, "Pages free")
      return nil if free_pages.nil?

      # Inactive/speculative/purgeable pages are reclaimable under pressure.
      reclaimable = free_pages +
        vm_stat_pages(vm, "Pages inactive").to_i +
        vm_stat_pages(vm, "Pages speculative").to_i +
        vm_stat_pages(vm, "Pages purgeable").to_i
      available = reclaimable * page_size
      used = total - available
      return nil if used.negative?

      ((used.to_f / total) * 100).round
    end
    module_function :darwin_memory_usage_percent

    def first_existing(*paths)
      paths.find { |path| File.readable?(path) }
    end
    module_function :first_existing

    def meminfo_kb(info, key)
      match = info.match(/^#{Regexp.escape(key)}:\s+(\d+)/)
      match && match[1].to_i
    end
    module_function :meminfo_kb

    def vm_stat_pages(vm, label)
      match = vm.match(/^#{Regexp.escape(label)}:\s+(\d+)/)
      match && match[1].to_i
    end
    module_function :vm_stat_pages
  end
end
