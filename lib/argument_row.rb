# frozen_string_literal: true

require "adwaita"
require_relative "translation"

# ArgumentRow is the row that names and edits one argument of a custom tool.
#
# Ported from the argument_list bind_model callback in upstream's
# src/widgets/preferences/ToolSettings.vala: the row is titled "Argument N",
# its suffix is a centred entry, and the entry is the row's activatable widget
# so clicking the row starts typing in it. Upstream binds the entry's text to
# the argument object bidirectionally; here the entry reports changes through
# the callback the tool settings pass in.
module ArgumentRow
  class << self
    def build(index, value, &on_change)
      entry(value, &on_change).then do |field|
        Adwaita::ActionRow.new.tap do |row|
          row.title = format(Translation.t("Argument %d"), index + 1)
          row.activatable_widget = field
          row.add_suffix(field)
        end
      end
    end

    private

      def entry(value, &on_change)
        Gtk::Entry.new.tap do |field|
          field.valign = :center
          field.text = value.to_s
          field.signal_connect("changed") { on_change&.call(field.text) }
        end
      end
  end
end
