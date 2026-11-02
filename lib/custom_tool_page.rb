# frozen_string_literal: true

require "adwaita"
require_relative "tool_settings"
require_relative "translation"

# CustomToolPage is the preferences subpage that edits an existing custom
# tool.
#
# Ported from upstream's src/widgets/preferences/pages/CustomToolPage.vala and
# resources/ui/CustomToolPage.blp: a header bar with a back button, the "Edit
# Tool" heading and a destructive Delete button, over the shared tool settings
# form with script editing enabled.
#
# Upstream saves on unmap — when the subpage is no longer visible — by
# re-emitting items-changed for the tool so its row redraws and committing the
# index to disk. Adwaita does not unmap a closed subpage promptly, so the
# preferences window calls #closed instead, at the same moment and with the
# same two steps.
class CustomToolPage
  def initialize(tool, preferences:, tools:)
    @tool = tool
    @preferences = preferences
    @tools = tools
  end

  def build
    root.tap do |box|
      box.append(header_bar)
      box.append(tool_settings.build)

      header_bar.tap do |bar|
        bar.pack_start(back_button)
        bar.title_widget = title_label
        bar.pack_end(delete_button)

        back_button.signal_connect("clicked") { go_back }
        delete_button.signal_connect("clicked") { delete_tool }
      end

    end
  end

  def widget = root

  # Called by the preferences window as the subpage closes: the row redraws
  # with the edited name and the index is written to disk.
  def closed
    @tools.notify_changed(@tool)
    @tools.commit
  rescue SystemCallError => e
    warn "Can't commit tools: #{e.message}"
    @preferences.add_toast(Adwaita::Toast.new(format(Translation.t("Error occured: %s"), e.message)))
  end

  # Memoized widget methods

  def root = @root ||= Gtk::Box.new(:vertical, 0)

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.show_start_title_buttons = false
      bar.show_end_title_buttons = false
    end
  end

  def back_button
    @back_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = "go-previous-symbolic"
    end
  end

  def title_label
    @title_label ||= Gtk::Label.new(Translation.t("Edit Tool")).tap do |label|
      label.add_css_class("heading")
    end
  end

  def delete_button
    @delete_button ||= Gtk::Button.new.tap do |button|
      button.label = Translation.t("D_elete")
      button.use_underline = true
      button.add_css_class("destructive-action")
    end
  end

  def tool_settings
    @tool_settings ||= ToolSettings.new(
      @tool,
      window:          @preferences.window,
      can_edit_script: true,
    )
  end

  private

    def go_back
      @preferences.close_subpage
    end

    def delete_tool
      @tools.delete_tool(@tool)
      go_back
    end
end
