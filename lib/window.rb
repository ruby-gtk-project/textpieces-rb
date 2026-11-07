# frozen_string_literal: true

require "adwaita"
require_relative "editor"
require_relative "preferences"
require_relative "search"
require_relative "shortcuts_window"
require_relative "translation"
require_relative "textpieces/rb/version"

# Window is the main window: the header bar with the apply and copy buttons
# and the tool button, the tool search below it, and the stack holding the
# editor and the tool chooser.
#
# Ported from upstream's src/widgets/Window.vala and
# resources/ui/Window.blp, including the window action set, the app menu, the
# about dialog, the load and save file dialogs and the selected-tool
# bookkeeping that stores the choice in the settings and survives the tool
# being deleted.
class Window
  # Text and icon used instead of a tool's own when no tool is selected.
  NO_TOOL_LABEL = "Select tool"
  NO_TOOL_ICON = "applications-utilities-symbolic"

  APP_ICON = "org.rubygtkproject.Textpieces"
  WEBSITE = "https://github.com/liferooter/textpieces"
  ISSUE_URL = "https://github.com/liferooter/textpieces/issues/new"

  # Upstream's ACTION_ENTRIES, plus show-help-overlay, which upstream gets for
  # free from the Gtk.ShortcutsWindow it sets as its help overlay.
  ACTIONS = {
    "apply"             => :action_apply,
    "open-preferences"  => :action_open_preferences,
    "about"             => :action_about,
    "copy"              => :action_copy,
    "tools-settings"    => :action_tools_settings,
    "toggle-search"     => :action_toggle_search,
    "save-as"           => :action_save_as,
    "load-file"         => :action_load_file,
    "jump-to-args"      => :action_jump_to_args,
    "find"              => :action_find,
    "show-help-overlay" => :action_show_help_overlay,
  }.freeze

  # The app menu of resources/ui/Window.blp, section by section.
  MENU = [
    [["_New Window", "app.new-window"]],
    [["_Find/Replace…", "win.find"]],
    [
      ["_Preferences", "win.open-preferences"],
      ["_Keyboard Shortcuts", "win.show-help-overlay"],
      ["_About Text Pieces", "win.about"],
    ],
  ].freeze

  attr_reader :selected_tool

  def initialize(application, settings:, tools:, accels: {})
    @application = application
    @settings = settings
    @tools = tools
    @accels = accels
  end

  def build
    window.tap do |win|
      win.content = content_box

      content_box.tap do |box|
        box.append(header_bar)
        box.append(tool_search_bar)
        box.append(content_stack)

        header_bar.tap do |bar|
          bar.pack_start(actions_revealer)
          bar.title_widget = tool_button
          bar.pack_end(menu_button)
          bar.pack_end(save_button)
          bar.pack_end(load_button)

          actions_revealer.child = actions_box

          actions_box.tap do |linked|
            linked.append(apply_button)
            linked.append(copy_button)
          end

          tool_button.tap do |toggle|
            toggle.child = tool_button_content
            toggle.signal_connect("toggled") { on_search_toggled }
          end
        end

        tool_search_bar.tap do |bar|
          bar.child = tool_search_entry
          bar.connect_entry(tool_search_entry)
          tool_button.bind_property(
            "active",
            bar,
            "search-mode-enabled",
            GLib::BindingFlags::BIDIRECTIONAL | GLib::BindingFlags::SYNC_CREATE,
          )
          bar.bind_property(
            "search-mode-enabled",
            actions_revealer,
            "reveal-child",
            GLib::BindingFlags::SYNC_CREATE | GLib::BindingFlags::INVERT_BOOLEAN,
          )
        end

        content_stack.tap do |stack|
          stack.add_named(editor.build, "editor")
          stack.add_named(search.build, "search")
        end
      end

      win.signal_connect("close-request") { on_close_request }

      register_actions
      watch_deleted_tools
      restore_selected_tool
    end
  end

  def present
    window.present
    editor.grab_focus
  end

  def save_window_size
    @settings.save_window_size(window)
  end

  # Replaces the editor's text with the file's contents, and says so in a
  # dialog when that cannot be done.
  def load_from(file)
    editor.load_from(file)
  rescue SystemCallError => e
    report_error("Can't load from file", e.message)
  end

  def selected_tool=(tool)
    @tool_observer.then do |observer|
      if observer
        @selected_tool&.off_change(observer)
      end
    end

    @selected_tool = tool
    @tool_observer = tool&.on_change { tool_changed }
    @settings["selected-tool"] = tool&.script.to_s
    tool_changed
  end

  # Memoized widget methods

  def window
    @window ||= Adwaita::ApplicationWindow.new(@application).tap do |win|
      win.title = Translation.t("Text Pieces")
      win.icon_name = APP_ICON
      @settings.apply_to(win)
    end
  end

  def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)
  def header_bar = @header_bar ||= Adwaita::HeaderBar.new

  def actions_revealer
    @actions_revealer ||= Gtk::Revealer.new.tap do |revealer|
      revealer.transition_type = :crossfade
    end
  end

  def actions_box
    @actions_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.add_css_class("linked")
    end
  end

  def apply_button
    @apply_button ||= Gtk::Button.new.tap do |button|
      button.label = Translation.t("_Apply")
      button.use_underline = true
      button.action_name = "win.apply"
      button.tooltip_text = Translation.t("Apply Selected Tool")
      button.add_css_class("suggested-action")
    end
  end

  def copy_button
    @copy_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = "edit-copy-symbolic"
      button.action_name = "win.copy"
      button.tooltip_text = Translation.t("Copy")
      button.add_css_class("suggested-action")
    end
  end

  def tool_button
    @tool_button ||= Gtk::ToggleButton.new.tap do |toggle|
      toggle.add_css_class("flat")
      toggle.add_css_class("heading")
    end
  end

  def tool_button_content = @tool_button_content ||= Adwaita::ButtonContent.new

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.icon_name = "open-menu-symbolic"
      button.tooltip_text = Translation.t("Main Menu")
      button.primary = true
      button.menu_model = menu_model
    end
  end

  def save_button
    @save_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = "document-save-symbolic"
      button.tooltip_text = Translation.t("Save to File")
      button.action_name = "win.save-as"
    end
  end

  def load_button
    @load_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = "document-open-symbolic"
      button.tooltip_text = Translation.t("Load from File")
      button.action_name = "win.load-file"
    end
  end

  def tool_search_bar = @tool_search_bar ||= Gtk::SearchBar.new
  def tool_search_entry = @tool_search_entry ||= Gtk::SearchEntry.new

  def content_stack
    @content_stack ||= Gtk::Stack.new.tap do |stack|
      stack.vexpand = true
      stack.transition_type = :crossfade
    end
  end

  def editor = @editor ||= Editor.new(@settings)

  def search
    @search ||= Search.new(
      @tools,
      tool_search_entry,
      on_tool_selected: method(:on_tool_selected),
    )
  end

  def menu_model
    @menu_model ||= Gio::Menu.new.tap do |menu|
      MENU.each do |section|
        menu.append_section(nil, menu_section(section))
      end
    end
  end

  # One preferences window per main window, so win.tools-settings reaches the
  # one already on screen rather than stacking a second copy on it.
  def preferences
    @preferences ||= Preferences.new(
      settings:    @settings,
      tools:       @tools,
      application: @application,
    )
  end

  # The about dialog of upstream's action_about, with the port's version and
  # the upstream project's details. It belongs to the application, so it shows
  # up in the application's window list and the shortcuts reach it.
  def about_window
    @about_window ||= Adwaita::AboutWindow.new.tap do |about|
      about.transient_for = window
      about.application = @application
      about.application_icon = APP_ICON
      about.application_name = Translation.t("Text Pieces")
      about.comments = Translation.t("Transform text without using random websites")
      about.version = Textpieces::Rb::VERSION
      about.license_type = Gtk::License::GPL_3_0
      about.website = WEBSITE
      about.issue_url = ISSUE_URL
      about.artists = [Translation.t("Tobias Bernard https://tobiasbernard.com")]
      about.developers = [Translation.t("Gleb Smirnov <glebsmirnov0708@gmail.com>")]
      about.developer_name = Translation.t("Gleb Smirnov")
      about.translator_credits = Translation.t("translator-credits")
    end
  end

  def apply_action
    @apply_action ||= Gio::SimpleAction.new("apply").tap do |action|
      action.signal_connect("activate") { action_apply }
    end
  end

  private

    # The underscores in the labels are the mnemonics the upstream template
    # marks with use-underline; GTK's menu items read them from the label.
    def menu_section(items)
      Gio::Menu.new.tap do |section|
        items.each { |label, action| section.append(Translation.t(label), action) }
      end
    end

    def register_actions
      window.add_action(apply_action)
      ACTIONS.except("apply").each do |name, method_name|
        window.add_action(
          Gio::SimpleAction.new(name).tap do |action|
            action.signal_connect("activate") { send(method_name) }
          end,
        )
      end
    end

    # Upstream connects to the controller's delete_tool signal so a deleted
    # tool does not stay selected.
    def watch_deleted_tools
      @tools.on_delete_tool do |tool|
        if tool == @selected_tool
          self.selected_tool = nil
        end
      end
    end

    # The tool the settings remember, if it is still there; upstream logs the
    # reset and selects nothing when it is gone.
    def restore_selected_tool
      @settings["selected-tool"].then do |script|
        if script.to_s.empty?
          self.selected_tool = nil
        else
          restore_tool_with_script(script)
        end
      end
    end

    def restore_tool_with_script(script)
      @tools.find_by_script(script).then do |tool|
        unless tool
          warn "Previously selected tool is not found, so will be reset"
        end
        self.selected_tool = tool
      end
    end

    # Upstream's tool_changed: the button follows the tool, applying is
    # disabled without one, and the argument entries are rebuilt — after which
    # the editor's top margin is remeasured once the new entries have a size.
    def tool_changed
      tool_button_content.tap do |content|
        content.label = @selected_tool&.translated_name || Translation.t(NO_TOOL_LABEL)
        content.icon_name = @selected_tool&.icon || NO_TOOL_ICON
      end

      apply_action.enabled = !@selected_tool.nil?
      editor.arguments = @selected_tool&.translated_arguments || []

      editor.schedule_margin_update
    end

    def on_tool_selected(tool)
      self.selected_tool = tool
      tool_button.active = false
    end

    # Upstream's on_search_toggled: the tool button swaps the stack between
    # the chooser and the editor, and leaving the chooser resets it.
    def on_search_toggled
      if tool_button.active?
        content_stack.visible_child_name = "search"
        tool_search_entry.grab_focus
      else
        content_stack.visible_child_name = "editor"
        search.reset
      end
    end

    def on_close_request
      save_window_size
      false
    end

    # Window actions

    def action_apply
      @selected_tool.then do |tool|
        if tool
          apply_tool(tool)
        end
      end
    end

    # A tool that wrote to stderr says so in a toast; one that failed leaves
    # the text alone.
    def apply_tool(tool)
      tool.apply(editor.selection, editor.arguments).then do |result|
        if result.error
          editor.show_message(result.error)
        end
        if result.output
          editor.replace_selection(result.output)
        end
      end
    end

    def action_copy = editor.copy_text
    def action_jump_to_args = editor.jump_to_args
    def action_find = editor.search_bar.show_search
    def action_toggle_search = tool_button.active = !tool_button.active?

    def action_open_preferences
      preferences.present(window)
    end

    def action_tools_settings
      preferences.tap do |prefs|
        prefs.present(window)
        prefs.visible_page_name = "custom-tools"
      end
    end

    def action_show_help_overlay
      ShortcutsWindow.new(@accels).present(window)
    end

    def action_about
      about_window.present
    end

    def action_save_as
      Gtk::FileDialog.new.tap do |dialog|
        dialog.title = Translation.t("Save to File")
        dialog.modal = true
        dialog.save(window, nil) { |_, result| save_to(dialog, result) }
      end
    end

    def action_load_file
      Gtk::FileDialog.new.tap do |dialog|
        dialog.title = Translation.t("Load from File")
        dialog.modal = true
        dialog.open(window, nil) { |_, result| load_chosen(dialog, result) }
      end
    end

    # A cancelled dialog raises rather than handing back a nil file, which is
    # the modern dialogs' answer to upstream's "response with no file".
    def save_to(dialog, result)
      editor.save_as(dialog.save_finish(result))
    rescue GLib::Error
      nil
    rescue SystemCallError => e
      report_error("Can't save to file", e.message)
    end

    def load_chosen(dialog, result)
      load_from(dialog.open_finish(result))
    rescue GLib::Error
      nil
    end

    # Upstream shows a modal warning dialog whose text is the failure; the
    # heading carries that sentence and the body the system's message.
    def report_error(heading, message)
      Adwaita::AlertDialog.new(Translation.t(heading), message).tap do |dialog|
        dialog.add_response("close", Translation.t("_Close"))
        dialog.default_response = "close"
        dialog.present(window)
      end
    end

end
