# frozen_string_literal: true

module Foundation
  module CrmHelper
    def crm_money(cents, currency = "USD")
      whole, fraction = Integer(cents || 0).divmod(100)
      "#{currency} #{whole}.#{format('%02d', fraction)}"
    end

    def crm_nav_items
      path = request.path
      [
        { label: "Overview", href: crm_root_path, active: path == crm_root_path },
        { label: "Contacts", href: crm_contacts_path, active: path.start_with?("/crm/contacts") },
        { label: "Companies", href: crm_companies_path, active: path.start_with?("/crm/companies") },
        { label: "Leads", href: crm_leads_path, active: path.start_with?("/crm/leads") },
        { label: "Opportunities", href: crm_opportunities_path, active: path.start_with?("/crm/opportunities") },
        { label: "Pipelines", href: crm_pipelines_path, active: path.start_with?("/crm/pipelines") },
        { label: "Tasks", href: crm_tasks_path, active: path.start_with?("/crm/tasks") },
        { label: "Tags", href: crm_tags_path, active: path.start_with?("/crm/tags") }
      ]
    end

    def crm_filter_link(label, path, active:)
      classes = class_names("md-chip", selected: active)
      link_to label, path, class: classes
    end

    def crm_user_label(user)
      user&.email || "Unassigned"
    end

    def crm_pagination(base_path:, page:, has_next:)
      return if page <= 1 && !has_next

      tag.nav class: "md-actions", aria: { label: "Pagination" } do
        safe_join([
          (page > 1 ? link_to("Previous", "#{base_path}#{base_path.include?('?') ? '&' : '?'}page=#{page - 1}", class: "md-button md-button--text") : nil),
          tag.span("Page #{page}", class: "text-md-on-surface-variant"),
          (has_next ? link_to("Next", "#{base_path}#{base_path.include?('?') ? '&' : '?'}page=#{page + 1}", class: "md-button md-button--text") : nil)
        ].compact)
      end
    end
  end
end
