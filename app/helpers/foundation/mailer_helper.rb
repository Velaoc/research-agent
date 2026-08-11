# frozen_string_literal: true

module Foundation
  # Inline-style helpers for transactional HTML mail. Values come from the
  # committed MD3 light scheme so mail matches the product UI without a
  # CSS-inlining gem (Gmail/Outlook strip <head> <style> blocks).
  module MailerHelper
    FONT_STACK = 'Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif'

    def mail_application_name
      Rails.configuration.x.foundation[:application_name]
    end

    def mail_support_email
      Rails.configuration.x.foundation[:support_email]
    end

    def mail_color(role, scheme: :light)
      mail_tokens(scheme).fetch(role.to_s)
    end

    def mail_css(declarations)
      declarations.filter_map { |property, value|
        next if value.nil?

        "#{property}: #{value}"
      }.join("; ")
    end

    def mail_body_style
      mail_css(
        "margin" => "0",
        "padding" => "0",
        "width" => "100%",
        "background-color" => mail_color("surface"),
        "color" => mail_color("on-surface"),
        "font-family" => FONT_STACK,
        "font-size" => "16px",
        "line-height" => "24px",
        "-webkit-text-size-adjust" => "100%",
        "-ms-text-size-adjust" => "100%"
      )
    end

    def mail_shell_style
      mail_css(
        "margin" => "0",
        "padding" => "32px 16px",
        "width" => "100%",
        "background-color" => mail_color("surface"),
        "border-collapse" => "collapse"
      )
    end

    def mail_card_style
      mail_css(
        "width" => "100%",
        "max-width" => "560px",
        "margin" => "0 auto",
        "background-color" => mail_color("surface-container-lowest"),
        "border" => "1px solid #{mail_color("outline-variant")}",
        "border-radius" => "16px",
        "border-collapse" => "separate",
        "overflow" => "hidden"
      )
    end

    def mail_header_style
      mail_css(
        "padding" => "24px 28px 16px",
        "background-color" => mail_color("surface-container-low"),
        "border-bottom" => "1px solid #{mail_color("outline-variant")}"
      )
    end

    def mail_brand_style
      mail_css(
        "margin" => "0",
        "color" => mail_color("on-surface"),
        "font-family" => FONT_STACK,
        "font-size" => "22px",
        "font-weight" => "650",
        "line-height" => "28px",
        "letter-spacing" => "-0.01em"
      )
    end

    def mail_content_style
      mail_css(
        "padding" => "28px",
        "background-color" => mail_color("surface-container-lowest"),
        "color" => mail_color("on-surface"),
        "font-family" => FONT_STACK,
        "font-size" => "16px",
        "line-height" => "24px",
        "text-align" => "left"
      )
    end

    def mail_footer_style
      mail_css(
        "padding" => "20px 28px 28px",
        "background-color" => mail_color("surface-container-lowest"),
        "border-top" => "1px solid #{mail_color("outline-variant")}",
        "color" => mail_color("on-surface-variant"),
        "font-family" => FONT_STACK,
        "font-size" => "12px",
        "line-height" => "16px",
        "text-align" => "left"
      )
    end

    def mail_heading_style
      mail_css(
        "margin" => "0 0 16px",
        "color" => mail_color("on-surface"),
        "font-family" => FONT_STACK,
        "font-size" => "22px",
        "font-weight" => "500",
        "line-height" => "28px"
      )
    end

    def mail_paragraph_style
      mail_css(
        "margin" => "0 0 16px",
        "color" => mail_color("on-surface"),
        "font-family" => FONT_STACK,
        "font-size" => "16px",
        "font-weight" => "400",
        "line-height" => "24px"
      )
    end

    def mail_muted_style
      mail_css(
        "margin" => "0 0 16px",
        "color" => mail_color("on-surface-variant"),
        "font-family" => FONT_STACK,
        "font-size" => "14px",
        "font-weight" => "400",
        "line-height" => "20px"
      )
    end

    def mail_list_style
      mail_css(
        "margin" => "0 0 16px",
        "padding" => "0 0 0 20px",
        "color" => mail_color("on-surface"),
        "font-family" => FONT_STACK,
        "font-size" => "16px",
        "line-height" => "24px"
      )
    end

    def mail_list_item_style
      mail_css(
        "margin" => "0 0 8px",
        "color" => mail_color("on-surface")
      )
    end

    def mail_strong_style
      mail_css(
        "color" => mail_color("on-surface"),
        "font-weight" => "600"
      )
    end

    def mail_link_style
      mail_css(
        "color" => mail_color("primary"),
        "font-weight" => "600",
        "text-decoration" => "underline"
      )
    end

    def mail_button_style
      mail_css(
        "display" => "inline-block",
        "padding" => "14px 24px",
        "background-color" => mail_color("primary"),
        "color" => mail_color("on-primary"),
        "font-family" => FONT_STACK,
        "font-size" => "14px",
        "font-weight" => "650",
        "line-height" => "20px",
        "text-align" => "center",
        "text-decoration" => "none",
        "border-radius" => "999px",
        "border" => "0"
      )
    end

    def mail_button_wrap_style
      mail_css(
        "margin" => "0 0 16px",
        "text-align" => "left"
      )
    end

    def mail_url_style
      mail_css(
        "margin" => "0 0 16px",
        "word-break" => "break-all",
        "color" => mail_color("on-surface-variant"),
        "font-family" => FONT_STACK,
        "font-size" => "12px",
        "line-height" => "16px"
      )
    end

    def mail_heading(text)
      tag.h1(text, style: mail_heading_style)
    end

    def mail_paragraph(&block)
      tag.p(style: mail_paragraph_style, &block)
    end

    def mail_muted(&block)
      tag.p(style: mail_muted_style, &block)
    end

    def mail_button(label, url)
      tag.p(style: mail_button_wrap_style) do
        link_to(label, url, style: mail_button_style, target: "_blank")
      end
    end

    def mail_text_link(label, url)
      link_to(label, url, style: mail_link_style)
    end

    private

    def mail_tokens(scheme)
      @mail_tokens ||= {}
      @mail_tokens[scheme] ||= JSON.parse(
        Rails.root.join("config/material_tokens.json").read
      ).fetch("schemes").fetch(scheme.to_s)
    end
  end
end
