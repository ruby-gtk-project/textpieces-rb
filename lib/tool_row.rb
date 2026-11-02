# frozen_string_literal: true

require "adwaita"

# ToolRow is the row a tool gets in the search results.
#
# Ported from build_list_row in upstream's src/tools/Tool.vala: the tool's
# translated name as the title, its translated description as the subtitle,
# its icon on the left, and the row activatable so a click selects the tool.
module ToolRow
  class << self
    def build(tool)
      Adwaita::ActionRow.new.tap do |row|
        row.title = tool.translated_name
        row.subtitle = tool.translated_description
        row.icon_name = tool.icon
        row.activatable = true
      end
    end
  end
end
