# frozen_string_literal: true

require "gtk4"

# Recoloring restyles the whole application from an editor style scheme.
#
# A direct port of upstream's src/utils/Recoloring.vala (originally Christian
# Hergert's): it reads the scheme's text and selection colours, derives the
# Adwaita named colours — window, headerbar, view, accent — from them and
# returns the CSS that defines them. Schemes whose name starts with "Adwaita"
# are left alone, because the stock Adwaita stylesheet already is that palette.
module Recoloring
  # CSS that should be loaded for any style scheme except Adwaita or
  # Adwaita-dark.
  SHARED_CSS = <<~CSS
    @define-color card_fg_color @window_fg_color;
    @define-color headerbar_fg_color @window_fg_color;
    @define-color headerbar_border_color @window_fg_color;
    @define-color popover_fg_color @window_fg_color;
    @define-color dark_fill_bg_color @headerbar_bg_color;
    @define-color view_bg_color @card_bg_color;
    @define-color view_fg_color @window_fg_color;
  CSS

  # CSS that should be loaded for any light style scheme except Adwaita.
  LIGHT_CSS_SUFFIX = <<~CSS
    @define-color popover_bg_color mix(@window_bg_color, white, .1);
    @define-color card_bg_color alpha(white, .6);
  CSS

  # CSS that should be loaded for any dark style scheme except Adwaita-dark.
  DARK_CSS_SUFFIX = <<~CSS
    @define-color popover_bg_color mix(@window_bg_color, white, 0.07);
    @define-color card_bg_color @popover_bg_color;
    @define-color view_bg_color darker(@window_bg_color);
  CSS

  BLACK = "rgb(0,0,0)"
  WHITE = "rgb(255,255,255)"

  class << self
    # Whether the scheme is dark: its "variant" metadata decides, then an
    # "-dark" id suffix, and failing both the perceived brightness of the text
    # background (http://alienryderflex.com/hsp.html).
    def scheme_dark?(scheme)
      case scheme.get_metadata("variant")
      when "light"
        false
      when "dark"
        true
      else
        dark_by_color?(scheme)
      end
    end

    # The CSS to apply for this scheme, or an empty string for the Adwaita
    # schemes, which need none.
    def generate_css(scheme)
      if scheme.name.to_s.start_with?("Adwaita")
        ""
      else
        build_css(scheme)
      end
    end

    private

      def dark_by_color?(scheme)
        if scheme.id.to_s.end_with?("-dark")
          true
        else
          color(scheme, "text", :background).then do |text_bg|
            if text_bg
              brightness(text_bg) <= 127.5
            else
              false
            end
          end
        end
      end

      def brightness(color)
        [color.red * 255.0, color.green * 255.0, color.blue * 255.0].then do |r, g, b|
          Math.sqrt((0.299 * r * r) + (0.587 * g * g) + (0.114 * b * b))
        end
      end

      def build_css(scheme)
        dark = scheme_dark?(scheme)
        alt = alternate(dark)
        text_bg = color(scheme, "text", :background) || fallback(dark, BLACK, WHITE)
        text_fg = color(scheme, "text", :foreground) || fallback(dark, WHITE, BLACK)

        [SHARED_CSS, "/* #{scheme.name} */\n"]
          .concat(window_colors(
            text_bg,
            text_fg,
            alt,
            dark,
          ))
          .concat(accent_colors(scheme, alt))
          .push(suffix(dark))
          .join
      end

      def alternate(dark)
        if dark
          parse(WHITE)
        else
          parse(BLACK)
        end
      end

      def fallback(dark, when_dark, when_light)
        if dark
          parse(when_dark)
        else
          parse(when_light)
        end
      end

      def window_colors(text_bg, text_fg, alt, dark)
        [].tap do |css|
          if dark
            css << define_color_mixed(
              "window_bg_color",
              text_bg,
              alt,
              0.025,
            )
          else
            css << define_color_mixed(
              "window_bg_color",
              text_bg,
              parse(WHITE),
              0.1,
            )
          end
          css << define_color_mixed(
            "headerbar_bg_color",
            text_bg,
            alt,
            0.05,
          )
          css << define_color_mixed(
            "window_fg_color",
            text_fg,
            alt,
            0.1,
          )
          css << define_color("headerbar_fg_color", text_fg)
          css << define_color_mixed(
            "view_bg_color",
            text_bg,
            parse(WHITE),
            view_mix(dark),
          )
          css << define_color("view_fg_color", text_fg)
        end
      end

      def view_mix(dark)
        if dark
          0.1
        else
          0.3
        end
      end

      # accent_bg_color and accent_fg_color come from the scheme's metadata
      # when it has them and from its selection style otherwise; accent_color
      # is the metadata value, or the accent background mixed towards the
      # alternate colour.
      def accent_colors(scheme, alt)
        [].tap do |css|
          css << define_color(
            "accent_bg_color",
            metadata_color(scheme, "accent_bg_color") || color(scheme, "selection", :background),
          )
          css << define_color(
            "accent_fg_color",
            metadata_color(scheme, "accent_fg_color") || color(scheme, "selection", :foreground),
          )
          css << accent_color(scheme, alt)
        end
      end

      def accent_color(scheme, alt)
        metadata_color(scheme, "accent_color").then do |explicit|
          if explicit
            define_color("accent_color", explicit)
          else
            derived_accent_color(scheme, alt)
          end
        end
      end

      def derived_accent_color(scheme, alt)
        (metadata_color(scheme, "accent_bg_color") ||
          color(scheme, "selection", :background)).then do |derived|
          if derived
            define_color_mixed(
              "accent_color",
              opaque(derived),
              alt,
              0.1,
            )
          else
            ""
          end
        end
      end

      def suffix(dark)
        if dark
          DARK_CSS_SUFFIX
        else
          LIGHT_CSS_SUFFIX
        end
      end

      # A colour from one of the scheme's styles. Upstream drops colours that
      # are nearly transparent, because mixing with them produces nothing
      # usable. GtkSource::Style's foreground/background are nil unless the
      # *_set? flag says the scheme actually set them, same as upstream's
      # foreground_set/background_set pair.
      def color(scheme, style_name, kind)
        scheme.get_style(style_name).then do |style|
          if style && style.public_send(:"#{kind}_set?")
            parse(style.public_send(kind)).then do |rgba|
              if rgba && rgba.alpha >= 0.1
                rgba
              end
            end
          end
        end
      end

      def metadata_color(scheme, key) = parse(scheme.get_metadata(key))

      def parse(text)
        if text.nil?
          nil
        else
          Gdk::RGBA.parse(text.to_s)
        end
      rescue ArgumentError, TypeError
        nil
      end

      def define_color(name, color)
        if color
          "@define-color #{name} #{opaque(color)};\n"
        else
          ""
        end
      end

      def define_color_mixed(name, first, second, level)
        "@define-color #{name} mix(#{first}, #{second}, #{level});\n"
      end

      # Upstream copies the colour and forces its alpha to 1 before writing it
      # out, so a translucent editor colour becomes a solid interface colour.
      def opaque(color)
        Gdk::RGBA.new(
          color.red,
          color.green,
          color.blue,
          1.0,
        )
      end
  end
end
