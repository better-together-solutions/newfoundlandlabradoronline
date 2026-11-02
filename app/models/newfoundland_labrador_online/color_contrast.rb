# frozen_string_literal: true

module NewfoundlandLabradorOnline
  # WCAG 2.x contrast maths. Mirrors BetterTogether::ColorContrast (Community Engine PR 2060); drop this once the
  # host app runs a gem release that has it.
  module ColorContrast
    LIGHT = '#ffffff'
    DARK = '#111111'

    module_function

    def text_color_for(background)
      contrast_ratio(background, LIGHT) >= contrast_ratio(background, DARK) ? LIGHT : DARK
    end

    def contrast_ratio(first, second)
      lighter, darker = [luminance(first), luminance(second)].sort.reverse
      (lighter + 0.05) / (darker + 0.05)
    end

    def luminance(hex)
      red, green, blue = hex.delete('#').scan(/../).map { |pair| linear(pair.hex / 255.0) }
      (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    end

    def linear(channel)
      channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055)**2.4
    end
  end
end
