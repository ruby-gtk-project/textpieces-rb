# frozen_string_literal: true

require "gtk4"

# Style is the application's own stylesheet.
#
# Ported from resources/style.css, which upstream loads from its gresource.
# The single rule is the floating card the argument entries and the search bar
# sit on, over the editor. (resources/style-dark.css is only a licence header
# upstream, so there is nothing to port from it.)
#
# The other two providers the application installs are generated rather than
# written: Recoloring's style-scheme CSS, and the editor font rule the Editor
# builds from the font-name setting.
module Style
  CSS = <<~CSS
    /* Argument view */

    .editor-overlay {
      padding: 6px;
      background-color: lighter(@window_bg_color);
      border-radius: 9px;
      box-shadow: 0 0 0 1px alpha(black, 0.03),
                  0 1px 3px 1px alpha(black, 0.07),
                  0 2px 6px 2px alpha(black, 0.03);
    }
  CSS

  class << self
    # Installs the stylesheet on the display at the application priority, the
    # same priority upstream's gresource stylesheet is loaded with.
    def install(display = Gdk::Display.default)
      if display
        Gtk::StyleContext.add_provider_for_display(
          display,
          provider,
          Gtk::StyleProvider::PRIORITY_APPLICATION,
        )
      end
      provider
    end

    def provider
      @provider ||= Gtk::CssProvider.new.tap { |css| css.load_from_string(CSS) }
    end
  end
end
