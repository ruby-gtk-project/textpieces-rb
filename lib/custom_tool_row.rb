# frozen_string_literal: true

require "adwaita"

# CustomToolRow is the row a custom tool gets in the preferences window.
#
# Ported from the custom_tools_listbox bind_model callback in upstream's
# src/widgets/preferences/Preferences.vala: the tool's translated name and
# description, a chevron on the right, and the row activatable so it opens the
# tool's settings subpage.
module CustomToolRow
  class << self
    def build(tool)
      Adwaita::ActionRow.new.tap do |row|
        row.title = tool.translated_name
        row.subtitle = tool.translated_description
        row.activatable = true
        row.add_suffix(Gtk::Image.new(icon_name: "go-next-symbolic"))
      end
    end
  end
end
