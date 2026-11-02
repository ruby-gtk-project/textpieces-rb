# frozen_string_literal: true

require "adwaita"
require_relative "custom_tool_page"
require_relative "custom_tool_row"
require_relative "new_tool_page"
require_relative "style_scheme"
require_relative "translation"

# Preferences is the preferences window: the editor settings and the list of
# custom tools.
#
# Ported from upstream's src/widgets/preferences/Preferences.vala and
# resources/ui/Preferences.blp: a General page with the font row, the wrap
# lines and tabs-to-spaces switches, the tab width spin button and the style
# scheme chooser, and a Tools page listing the custom tools with an Add button
# and a "No Custom Tools" status page in place of an empty list.
#
# Upstream's chooser is GtkSource.StyleSchemeChooserWidget, which has no Ruby
# bindings; the schemes the port ships are listed in a boxed list instead and
# picking one writes the style-scheme setting, which is what the upstream
# property binding ends up doing.
class Preferences
  CLAMP_SIZE = 450
  TAB_WIDTH_MIN = 1
  TAB_WIDTH_MAX = 21

  # The subpage currently presented, if any — upstream's present_subpage keeps
  # no reference to it, but the page object owns the widgets its handlers
  # touch, so it has to stay reachable from Ruby.
  attr_reader :subpage

  def initialize(settings:, tools:, application: nil)
    @settings = settings
    @tools = tools
    @application = application
  end

  # Idempotent: the window is assembled once, however often the preferences
  # action is invoked.
  def build = @built ||= assemble

  def present(parent)
    build.tap do |prefs|
      prefs.transient_for = parent
      if @application
        prefs.application = @application
      end
      prefs.present
    end
  end

  def visible_page_name=(name)
    window.visible_page_name = name
  end

  # The subpage gets a chance to save what it holds before it goes.
  def close_subpage
    @subpage.then do |page|
      if page.respond_to?(:closed)
        page.closed
      end
    end
    window.close_subpage
  end
  def add_toast(toast) = window.add_toast(toast)

  def assemble
    window.tap do |prefs|
      prefs.add(general_page)
      prefs.add(tools_page)
      prefs.insert_action_group("prefs", action_group)

      general_page.tap do |page|
        page.add(editor_group)
        page.add(appearance_group)

        editor_group.tap do |group|
          group.add(font_row)
          group.add(wrap_lines_row)
          group.add(tabs_to_spaces_row)
          group.add(tab_width_row)
        end

        appearance_group.add(scheme_clamp)
        scheme_clamp.child = scheme_listbox
        build_scheme_rows
      end

      tools_page.add(tools_group)

      tools_group.tap do |group|
        group.header_suffix = add_tool_button
        group.add(custom_tools_listbox)
        group.add(empty_page)

        custom_tools_listbox.bind_model(@tools.custom_tools) { |tool| CustomToolRow.build(tool) }
        custom_tools_listbox.signal_connect("row-activated") { |_, row| edit_tool(row) }
        add_tool_button.signal_connect("clicked") { add_new_tool }
        @tools.custom_tools.signal_connect("items-changed") { update_tools_visibility }
      end

      bind_settings
      update_tools_visibility
    end
  end

  # Memoized widget methods

  def window
    @window ||= Adwaita::PreferencesWindow.new.tap do |prefs|
      prefs.title = Translation.t("Preferences")
      prefs.can_navigate_back = true
      prefs.modal = true
    end
  end

  def general_page
    @general_page ||= Adwaita::PreferencesPage.new.tap do |page|
      page.title = Translation.t("_General")
      page.use_underline = true
      page.name = "general-settings"
      page.icon_name = "preferences-symbolic"
    end
  end

  def tools_page
    @tools_page ||= Adwaita::PreferencesPage.new.tap do |page|
      page.title = Translation.t("T_ools")
      page.use_underline = true
      page.name = "custom-tools"
      page.icon_name = "applications-utilities-symbolic"
    end
  end

  def editor_group
    @editor_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = Translation.t("Editor")
    end
  end

  def appearance_group
    @appearance_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = Translation.t("Appearance")
    end
  end

  def tools_group
    @tools_group ||= Adwaita::PreferencesGroup.new.tap do |group|
      group.title = Translation.t("Custom tools")
    end
  end

  def font_row
    @font_row ||= Adwaita::ActionRow.new.tap do |row|
      row.title = Translation.t("Editor _Font")
      row.use_underline = true
      row.activatable = true
      row.action_name = "prefs.select-font"
      row.add_suffix(font_box)

      font_box.tap do |box|
        box.append(font_label)
        box.append(Gtk::Image.new(icon_name: "go-next-symbolic"))
      end
    end
  end

  def font_box
    @font_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
      box.valign = :center
    end
  end

  def font_label = @font_label ||= Gtk::Label.new

  def wrap_lines_row
    @wrap_lines_row ||= switch_row("_Wrap Lines", wrap_lines_switch)
  end

  def tabs_to_spaces_row
    @tabs_to_spaces_row ||= switch_row("Tabs to _Spaces", tabs_to_spaces_switch)
  end

  def wrap_lines_switch = @wrap_lines_switch ||= setting_switch
  def tabs_to_spaces_switch = @tabs_to_spaces_switch ||= setting_switch

  def tab_width_row
    @tab_width_row ||= Adwaita::ActionRow.new.tap do |row|
      row.title = Translation.t("_Tab Width in Spaces")
      row.use_underline = true
      row.activatable_widget = tab_width_spin
      row.add_suffix(tab_width_spin)
    end
  end

  def tab_width_spin
    @tab_width_spin ||= Gtk::SpinButton.new(tab_width_adjustment, 1, 0).tap do |spin|
      spin.valign = :center
    end
  end

  def tab_width_adjustment
    @tab_width_adjustment ||= Gtk::Adjustment.new(
      TAB_WIDTH_MIN,
      TAB_WIDTH_MIN,
      TAB_WIDTH_MAX,
      1,
      1,
      0,
    )
  end

  def scheme_clamp
    @scheme_clamp ||= Adwaita::Clamp.new.tap do |clamp|
      clamp.maximum_size = CLAMP_SIZE
    end
  end

  def scheme_listbox
    @scheme_listbox ||= Gtk::ListBox.new.tap do |list|
      list.add_css_class("boxed-list")
      list.selection_mode = :none
    end
  end

  def custom_tools_listbox
    @custom_tools_listbox ||= Gtk::ListBox.new.tap do |list|
      list.add_css_class("boxed-list")
      list.selection_mode = :none
    end
  end

  def empty_page
    @empty_page ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = "applications-utilities-symbolic"
      page.title = Translation.t("No Custom Tools")
      page.description = Translation.t("You can create one")
      page.vexpand = true
      page.valign = :center
    end
  end

  def add_tool_button
    @add_tool_button ||= Gtk::Button.new.tap do |button|
      button.add_css_class("flat")
      button.child = Adwaita::ButtonContent.new.tap do |content|
        content.icon_name = "list-add-symbolic"
        content.label = Translation.t("_Add custom tool")
        content.use_underline = true
      end
    end
  end

  def action_group
    @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
      group.add_action(
        Gio::SimpleAction.new("select-font").tap do |action|
          action.signal_connect("activate") { action_select_font }
        end,
      )
    end
  end

  private

    def switch_row(title, toggle)
      Adwaita::ActionRow.new.tap do |row|
        row.title = Translation.t(title)
        row.use_underline = true
        row.activatable_widget = toggle
        row.add_suffix(toggle)
      end
    end

    def setting_switch
      Gtk::Switch.new.tap do |toggle|
        toggle.valign = :center
      end
    end

    # Upstream binds these to GSettings, and its two switches to settings
    # actions; the settings object notifies its subscribers either way.
    def bind_settings
      @settings.subscribe("font-name") { |font| font_label.label = font.to_s }
      @settings.subscribe("wrap-lines") { |wrap| wrap_lines_switch.active = wrap }
      @settings.subscribe("tabs-to-spaces") { |spaces| tabs_to_spaces_switch.active = spaces }
      @settings.subscribe("spaces-in-tab") { |width| tab_width_spin.value = width }

      wrap_lines_switch.signal_connect("notify::active") do
        @settings["wrap-lines"] = wrap_lines_switch.active?
      end
      tabs_to_spaces_switch.signal_connect("notify::active") do
        @settings["tabs-to-spaces"] = tabs_to_spaces_switch.active?
      end
      tab_width_spin.signal_connect("value-changed") do
        @settings["spaces-in-tab"] = tab_width_spin.value.to_i
      end
    end

    # One row per shipped style scheme, with a check against the one in use.
    def build_scheme_rows
      StyleScheme.all.each do |scheme|
        scheme_listbox.append(scheme_row(scheme))
      end
      mark_selected_scheme(@settings["style-scheme"])
      @settings.subscribe("style-scheme") { |id| mark_selected_scheme(id) }
    end

    def scheme_row(scheme)
      Adwaita::ActionRow.new.tap do |row|
        row.title = scheme.name
        row.subtitle = scheme.description.to_s
        row.activatable = true
        row.add_suffix(scheme_check(scheme))
        row.signal_connect("activated") { @settings["style-scheme"] = scheme.id }
        scheme_rows[scheme.id] = row
      end
    end

    def scheme_check(scheme)
      Gtk::Image.new(icon_name: "object-select-symbolic").tap do |image|
        image.valign = :center
        scheme_checks[scheme.id] = image
      end
    end

    def scheme_rows = @scheme_rows ||= {}
    def scheme_checks = @scheme_checks ||= {}

    def mark_selected_scheme(id)
      scheme_checks.each { |scheme_id, image| image.visible = scheme_id == id }
    end

    # Upstream's action_select_font asks for a family only and stores its
    # name, which is what Gtk::FontDialog#choose_family returns.
    def action_select_font
      Gtk::FontDialog.new.tap do |dialog|
        dialog.title = Translation.t("Select font")
        dialog.modal = true
        dialog.choose_family(window, nil) { |_, result| store_font(dialog, result) }
      end
    end

    def store_font(dialog, result)
      dialog.choose_family_finish(result).then do |family|
        if family
          @settings["font-name"] = family.name
        end
      end
    rescue GLib::Error
      nil
    end

    # Upstream hides the list when there are no custom tools, which reveals
    # the status page bound to its inverted visibility.
    def update_tools_visibility
      @tools.custom.any?.then do |any|
        custom_tools_listbox.visible = any
        empty_page.visible = !any
      end
    end

    def add_new_tool
      NewToolPage.new(preferences: self, tools: @tools).tap do |page|
        @subpage = page
        window.present_subpage(page.build)
      end
    end

    def edit_tool(row)
      @tools.custom[row.index].then do |tool|
        if tool
          CustomToolPage.new(tool, preferences: self, tools: @tools).tap do |page|
            @subpage = page
            window.present_subpage(page.build)
          end
        end
      end
    end
end
