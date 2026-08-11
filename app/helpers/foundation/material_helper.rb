module Foundation
  module MaterialHelper
    MATERIAL_SYMBOLS = {
      "account_circle" => 0xF20B, "add" => 0xE145, "arrow_back" => 0xE5C4,
      "check" => 0xE668, "check_circle" => 0xF0BE, "close" => 0xE5CD,
      "dark_mode" => 0xE51C, "delete" => 0xE92E, "edit" => 0xF097,
      "error" => 0xF8B6, "expand_more" => 0xE5CF, "help" => 0xE8FD,
      "home" => 0xE9B2, "info" => 0xE88E, "light_mode" => 0xE518,
      "logout" => 0xE9BA, "menu" => 0xE5D2, "more_vert" => 0xE5D4,
      "notifications" => 0xE7F5, "open_in_new" => 0xE89E, "payments" => 0xEF63,
      "person" => 0xF0D3, "search" => 0xEF7A, "settings" => 0xE8B8,
      "task_alt" => 0xE2E6, "warning" => 0xF083, "workspaces" => 0xEA0F
    }.freeze

    BUTTON_VARIANTS = %i[filled tonal outlined text elevated].freeze
    CARD_VARIANTS = %i[elevated filled outlined].freeze
    CHOICE_TYPES = %i[checkbox radio switch].freeze
    SYMBOL_SIZES = [ 20, 24, 28, 32, 40, 48 ].freeze

    def material_symbol(name, size: 24, fill: false, label: nil, **attributes)
      glyph = name.to_s
      codepoint = MATERIAL_SYMBOLS[glyph]
      raise ArgumentError, "unknown Material Symbol: #{glyph}" unless codepoint

      pixel_size = Integer(size)
      raise ArgumentError, "unsupported symbol size: #{pixel_size}" unless SYMBOL_SIZES.include?(pixel_size)

      css_class = class_names("material-symbol", "material-symbol--#{pixel_size}", attributes.delete(:class), filled: fill)
      accessibility = label.present? ? { role: "img", aria: { label: label } } : { aria: { hidden: true } }

      tag.span(codepoint.chr(Encoding::UTF_8),
        **attributes,
        **accessibility,
        class: css_class)
    end

    def md_button(label = nil, href: nil, variant: :filled, icon: nil, loading: false, disabled: false, **attributes)
      variant = variant.to_sym
      raise ArgumentError, "unknown button variant: #{variant}" unless BUTTON_VARIANTS.include?(variant)

      render "foundation/components/button",
        label: label,
        href: href,
        variant: variant,
        icon: icon,
        loading: loading,
        disabled: disabled,
        attributes: attributes
    end

    def md_icon_button(icon, label:, selected: false, disabled: false, **attributes)
      render "foundation/components/icon_button",
        icon: icon, label: label, selected: selected, disabled: disabled, attributes: attributes
    end

    def md_text_field(form, attribute, label:, hint: nil, type: :text, **options)
      render "foundation/components/text_field",
        form: form, attribute: attribute, label: label, hint: hint, type: type, options: options
    end

    def md_select(form, attribute, choices, label:, hint: nil, **options)
      render "foundation/components/select",
        form: form, attribute: attribute, choices: choices, label: label, hint: hint, options: options
    end

    def md_choice(form, attribute, label:, type: :checkbox, value: "1", **options)
      type = type.to_sym
      raise ArgumentError, "unknown choice type: #{type}" unless CHOICE_TYPES.include?(type)

      render "foundation/components/choice",
        form: form, attribute: attribute, label: label, type: type, value: value, options: options
    end

    def md_card(variant: :elevated, **attributes, &block)
      variant = variant.to_sym
      raise ArgumentError, "unknown card variant: #{variant}" unless CARD_VARIANTS.include?(variant)

      render "foundation/components/card", variant: variant, attributes: attributes, content: capture(&block)
    end

    def md_chip(label, selected: false, removable: false, **attributes)
      render "foundation/components/chip",
        label: label, selected: selected, removable: removable, attributes: attributes
    end

    def md_progress(label: "Loading", value: nil)
      render "foundation/components/progress", label: label, value: value
    end

    def md_dialog(id:, title:, trigger_label:, actions: nil, &block)
      render "foundation/components/dialog",
        id: id, title: title, trigger_label: trigger_label, actions: actions, content: capture(&block)
    end

    def md_tooltip(label, text, **attributes)
      render "foundation/components/tooltip", label: label, text: text, attributes: attributes
    end
  end
end
