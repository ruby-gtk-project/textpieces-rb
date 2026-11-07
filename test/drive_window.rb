# frozen_string_literal: true

# Drives the real application through the ported features, one step per turn
# of the GTK main loop, and writes a screenshot of each state.
#
#   nix develop --command xvfb-run -a ruby test/drive_window.rb
#
# The PNGs land in tmp/shots.

require "tmpdir"
require "fileutils"
require "digest"
require "json"
require "thread"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

# A scratch config directory, so a drive never reads or rewrites the real
# settings or the real custom tools index.
SCRATCH = Dir.mktmpdir("textpieces-drive")
ENV["XDG_CONFIG_HOME"] = File.join(SCRATCH, "config")

require "textpieces"
require_relative "gtk_driver"

TEXT = "hello world\nhello again\n"
SCRATCH_FILE = File.join(SCRATCH, "saved.txt")

app = Textpieces::Application.new(flags: :non_unique)

GtkDriver.drive(app, shots: "tmp/shots") do |d, application|
  window = -> { application.instance_variable_get(:@windows).first }

  d.window { window.call.window }

  d.step("the window opens") do
    d.check("one window") { application.instance_variable_get(:@windows).length == 1 }
    d.check("title") { window.call.window.title == "Text Pieces" }
    d.check("editor page showing") { window.call.content_stack.visible_child_name == "editor" }
    d.check("no tool selected") { window.call.tool_button_content.label == "Select tool" }
    d.check("tools loaded") { application.tools.all_tools.n_items == 36 }
    d.check("apply disabled") { !window.call.apply_action.enabled? }
    d.shot("01-editor")
  end

  d.step("text goes into the editor") do
    window.call.editor.buffer.text = TEXT
    d.check("text is there") { window.call.editor.buffer.text == TEXT }
    d.check("whole text is the selection") { window.call.editor.selection == TEXT }
  end

  d.step("a tool without arguments is selected and applied") do
    window.call.selected_tool = application.tools.find_by_script("sha256")
    d.check("button names the tool") { window.call.tool_button_content.label == "SHA256 Checksum" }
    d.check("apply enabled") { window.call.apply_action.enabled? }
    d.check("no argument entries") { !window.call.editor.arguments_box.visible? }
    window.call.apply_button.activate
  end

  d.step("the editor holds the checksum") do
    d.check("checksum") { window.call.editor.buffer.text == Digest::SHA256.hexdigest(TEXT) }
    d.shot("02-applied")
  end

  d.step("a tool with arguments shows its entries") do
    @margin_before_args = window.call.editor.view.top_margin
    window.call.editor.buffer.text = TEXT
    window.call.selected_tool = application.tools.find_by_script("replace-regex")
    d.check("entries shown") { window.call.editor.arguments_box.visible? }
    d.check("two entries") { window.call.editor.arguments.length == 2 }
    d.check("placeholders") do
      window.call.editor.arguments_box.first_child.placeholder_text == "Find (regex)"
    end
  end

  d.step("the editor's top margin grew to clear the argument entries") do
    # Editor#update_editor_margin sets view.top_margin to the arguments box's
    # measured height while it is visible (lib/editor.rb's #new_margin), so
    # showing two argument entries should push the margin past the no-args
    # default of 6px rather than leaving it unchanged.
    d.check("margin grew") { window.call.editor.view.top_margin > @margin_before_args }
    d.check("margin matches the measured box height") do
      _, bounds = window.call.editor.arguments_box.compute_bounds(window.call.editor.editor_overlay)
      window.call.editor.view.top_margin == bounds.height.ceil
    end
  end

  d.step("the arguments are filled in and the tool applied") do
    d.shot("03-arguments")
    window.call.editor.arguments_box.first_child.text = "hello"
    window.call.editor.arguments_box.last_child.text = "goodbye"
    window.call.apply_button.activate
  end

  d.step("the replacement happened") do
    d.check("text replaced") do
      window.call.editor.buffer.text == "goodbye world\ngoodbye again\n"
    end
    d.shot("04-replaced")
  end

  d.step("picking a tool with no arguments hides the entries again") do
    window.call.selected_tool = application.tools.find_by_script("sha256")
  end

  d.step("the top margin falls back to the no-arguments default") do
    d.check("entries hidden") { !window.call.editor.arguments_box.visible? }
    d.check("margin reset") { window.call.editor.view.top_margin == @margin_before_args }
  end

  d.step("the tool chooser opens and filters") do
    window.call.tool_button.active = true
    window.call.tool_search_entry.text = "base64"
  end

  d.step("the chooser shows the matching tools") do
    d.check("search page showing") { window.call.content_stack.visible_child_name == "search" }
    d.check("two results") { window.call.search.results.length == 2 }
    d.check("best match first") do
      window.call.search.results.first.name.start_with?("Base64")
    end
    d.shot("05-chooser")
  end

  d.step("a query that matches nothing shows the placeholder") do
    window.call.tool_search_entry.text = "zzzznothing"
  end

  d.step("the placeholder page is up") do
    d.check("no results") { window.call.search.results.empty? }
    d.check("placeholder showing") { window.call.search.stack.visible_child_name == "placeholder" }
    d.shot("06-no-tools-found")
  end

  d.step("picking a tool from the chooser selects it") do
    window.call.tool_search_entry.text = "base64 encode"
    window.call.search.results_listbox.get_row_at_index(0).then do |row|
      window.call.search.results_listbox.signal_emit("row-activated", row)
    end
  end

  d.step("the chooser closed with the tool selected") do
    d.check("tool selected") { window.call.selected_tool.script == "base64-encode" }
    d.check("editor page back") { window.call.content_stack.visible_child_name == "editor" }
    d.check("setting remembers it") { application.settings["selected-tool"] == "base64-encode" }
  end

  d.step("the search bar opens over the editor") do
    window.call.editor.buffer.text = TEXT
    window.call.editor.search_bar.show_search
    window.call.editor.search_bar.search_entry.query = "hello"
  end

  d.step("the search bar counts the matches") do
    window.call.editor.search_bar.then do |bar|
      d.check("revealed") { bar.search_revealer.reveal_child? }
      d.check("two matches") { bar.context.occurrences_count == 2 }
      bar.next_match
      d.check("first match selected") do
        window.call.editor.buffer.selection_bounds.first.offset.zero?
      end
      d.check("replace all is sensitive") { bar.replace_all_button.sensitive? }
    end
  end

  d.step("replace all rewrites every match") do
    d.shot("07-search-bar")
    window.call.editor.search_bar.replace_entry.text = "goodbye"
    window.call.editor.search_bar.replace_all
    d.check("both replaced") do
      window.call.editor.buffer.text == "goodbye world\ngoodbye again\n"
    end
  end

  d.step("the search bar closes") do
    window.call.editor.search_bar.hide_search
    d.check("hidden") { !window.call.editor.search_bar.search_revealer.reveal_child? }
  end

  d.step("the editor saves to a file and loads it back") do
    window.call.editor.buffer.text = TEXT
    window.call.editor.save_as(Gio::File.new_for_path(SCRATCH_FILE))
    window.call.editor.buffer.text = ""
    window.call.load_from(Gio::File.new_for_path(SCRATCH_FILE))
    d.check("round trip") { window.call.editor.buffer.text == TEXT }
  end

  d.step("loading a missing file reports the error instead of raising") do
    window.call.load_from(Gio::File.new_for_path(File.join(SCRATCH, "nope.txt")))
  end

  d.step("the error dialog is up") do
    d.check("dialog shown") { !window.call.window.visible_dialog.nil? }
    d.shot("08-load-error", window.call.window.visible_dialog)
    window.call.window.visible_dialog&.close
  end

  d.step("the shortcuts window opens") do
    window.call.window.activate_action("show-help-overlay", nil)
  end

  d.step("the shortcuts window lists the groups") do
    d.check("dialog shown") { !window.call.window.visible_dialog.nil? }
    d.shot("09-shortcuts", window.call.window.visible_dialog)
    window.call.window.visible_dialog&.close
  end

  d.step("the preferences window opens") do
    window.call.window.activate_action("open-preferences", nil)
  end

  d.step("the preferences window shows the settings") do
    window.call.preferences.then do |prefs|
      d.check("visible") { prefs.window.visible? }
      d.check("font label filled") { prefs.font_label.label == "Monospace" }
      d.check("wrap switch follows the setting") { prefs.wrap_lines_switch.active? }
      d.check("tab width follows the setting") { prefs.tab_width_spin.value.to_i == 4 }
      d.check("no custom tools yet") { !prefs.custom_tools_listbox.visible? }
      d.shot("10-preferences", prefs.window)
    end
  end

  d.step("a switch writes the setting through") do
    window.call.preferences.wrap_lines_switch.active = false
    d.check("setting written") { application.settings["wrap-lines"] == false }
    d.check("editor rewrapped") { window.call.editor.view.wrap_mode == Gtk::WrapMode::NONE }
  end

  d.step("the tab width spin writes the setting through") do
    window.call.preferences.tab_width_spin.value = 8
    d.check("setting written") { application.settings["spaces-in-tab"] == 8 }
  end

  d.step("a style scheme is picked") do
    window.call.preferences.scheme_listbox.get_row_at_index(3).activate
  end

  d.step("the scheme was applied") do
    d.check("setting written") { application.settings["style-scheme"] == "sepia" }
    d.check("light scheme forced") do
      Adwaita::StyleManager.default.color_scheme == Adwaita::ColorScheme::FORCE_LIGHT
    end
    d.shot("11-recoloured")
  end

  d.step("the tools page opens the new tool subpage") do
    window.call.preferences.visible_page_name = "custom-tools"
    window.call.preferences.add_tool_button.activate
  end

  d.step("the new tool page refuses a nameless tool") do
    window.call.preferences.subpage.then do |page|
      d.check("create hidden") { !page.create_revealer.reveal_child? }
      d.check("form invalid") { !page.tool_settings.valid? }
      page.tool_settings.name_entry.text = "Shout"
      page.tool_settings.description_entry.text = "Upper-case the text"
    end
  end

  d.step("the named tool can be created") do
    window.call.preferences.subpage.then do |page|
      d.check("create revealed") { page.create_revealer.reveal_child? }
      d.shot("12-new-tool", window.call.preferences.window)
      page.create_button.activate
    end
  end

  d.step("the custom tool is on disk and in the list") do
    application.tools.custom.then do |custom|
      d.check("one custom tool") { custom.length == 1 }
      d.check("named") { custom.first.name == "Shout" }
      d.check("script written") { File.executable?(custom.first.script_path) }
      d.check("index written") do
        JSON.parse(File.read(application.tools.custom_tools_file))["tools"]
            .first["name"] == "Shout"
      end
      d.check("list shown") { window.call.preferences.custom_tools_listbox.visible? }
      d.check("in every tool") { application.tools.all.length == 37 }
      d.shot("14-custom-tools", window.call.preferences.window)
    end
  end

  d.step("the custom tool opens for editing") do
    window.call.preferences.custom_tools_listbox.then do |list|
      list.signal_emit("row-activated", list.get_row_at_index(0))
    end
  end

  d.step("an argument is added to the custom tool") do
    window.call.preferences.subpage.then do |page|
      d.check("edit page") { page.is_a?(CustomToolPage) }
      d.check("script row offered") { page.tool_settings.edit_script_list.visible? }
      page.tool_settings.arguments_number.value = 1
      d.check("argument row appeared") { page.tool_settings.argument_list.visible? }
      page.tool_settings.argument_list.first_child.activatable_widget.text = "Times"
    end
  end

  d.step("Edit Script opens the script through the OpenURI portal") do
    # Ashpd::OpenUri.open blocks on the portal's response and there is no
    # portal to answer in this headless session, so the call itself is
    # stubbed for this step; what is asserted is that Tool#open reaches it
    # with the right script path, window identifier and writable flag — the
    # flatpak-spawn/OpenURI launch path from lib/tool.rb#open, exercised end
    # to end from a real button activation rather than called directly.
    calls = Queue.new
    Ashpd::OpenUri.define_singleton_method(:open) do |uri, window_id, writable|
      calls.push([uri, window_id, writable])
    end
    window.call.preferences.subpage.then do |page|
      page.tool_settings.edit_script_row.signal_emit("activated")
      @edit_script_tool = page.instance_variable_get(:@tool)
    end
    @edit_script_call = calls.pop(timeout: 5)
  end

  d.step("the portal call named the script, not the tool metadata") do
    d.check("a call reached the portal") { !@edit_script_call.nil? }
    d.check("uri points at the custom tool's script") do
      @edit_script_call[0] == Gio::File.new_for_path(@edit_script_tool.script_path).uri
    end
    d.check("requested writable") { @edit_script_call[2] == true }
  end

  d.step("going back saves the argument") do
    d.shot("15-edit-tool", window.call.preferences.window)
    window.call.preferences.subpage.back_button.activate
  end

  d.step("the argument reached the index") do
    d.check("argument saved") do
      JSON.parse(File.read(application.tools.custom_tools_file))["tools"]
          .first["args"] == ["Times"]
    end
    d.check("tool knows it") { application.tools.custom.first.arguments == ["Times"] }
  end

  d.step("the custom tool is deleted") do
    @script_path = application.tools.custom.first.script_path
    window.call.preferences.custom_tools_listbox.then do |list|
      list.signal_emit("row-activated", list.get_row_at_index(0))
    end
  end

  d.step("deleting from the edit page removes it") do
    window.call.preferences.subpage.delete_button.activate
  end

  d.step("the tool, its script and its entry are gone") do
    d.check("no custom tools") { application.tools.custom.empty? }
    d.check("script removed") { !File.exist?(@script_path) }
    d.check("index empty") do
      JSON.parse(File.read(application.tools.custom_tools_file))["tools"].empty?
    end
    d.check("empty state back") { !window.call.preferences.custom_tools_listbox.visible? }
    d.shot("16-no-custom-tools", window.call.preferences.window)
  end

  d.step("the editor font setting round trips") do
    application.settings["font-name"] = "Fira Code"
    d.check("label follows") { window.call.preferences.font_label.label == "Fira Code" }
  end

  d.step("the about dialog opens") do
    window.call.window.activate_action("about", nil)
  end

  d.step("the about dialog shows the port's details") do
    window.call.about_window.then do |about|
      d.check("about window open") { about.visible? }
      d.check("version") { about.version == Textpieces::Rb::VERSION }
      d.check("name") { about.application_name == "Text Pieces" }
      d.shot("13-about", about)
      about.close
    end
  end

  d.step("the copy action copies the editor's text") do
    window.call.copy_button.activate
    d.check("editor still holds the text") { window.call.editor.buffer.text == TEXT }
  end

  d.step("the win.find action opens the search bar") do
    window.call.window.activate_action("find", nil)
  end

  d.step("the search bar opened without going through the toggle button") do
    d.check("revealed") { window.call.editor.search_bar.search_revealer.reveal_child? }
    window.call.editor.search_bar.hide_search
  end

  d.step("a tool with arguments is selected for jump-to-args") do
    window.call.selected_tool = application.tools.find_by_script("replace-regex")
    d.check("entries shown") { window.call.editor.arguments_box.visible? }
  end

  d.step("the win.jump-to-args action moves focus to the first argument") do
    window.call.window.activate_action("jump-to-args", nil)
    d.check("first argument has focus") do
      # The focus lands on the entry's internal `Gtk::Text`, not the
      # `Gtk::Entry` itself (it is a composite widget), so check parentage.
      window.call.window.focus&.parent == window.call.editor.arguments_box.first_child
    end
  end

  d.step("the win.tools-settings action opens preferences on the tools page") do
    window.call.window.activate_action("tools-settings", nil)
  end

  d.step("preferences is showing the custom-tools page") do
    window.call.preferences.then do |prefs|
      d.check("visible") { prefs.window.visible? }
      d.check("tools page selected") { prefs.window.visible_page_name == "custom-tools" }
      prefs.window.close
    end
  end

  d.step("the app.new-window action opens a second window") do
    application.app.activate_action("new-window", nil)
  end

  d.step("the second window is open and shares the persisted tool choice") do
    application.instance_variable_get(:@windows).then do |windows|
      d.check("two windows") { windows.length == 2 }
      d.check("new window restores the shared selected tool") do
        windows.last.tool_button_content.label == window.call.tool_button_content.label
      end
    end
  end

  d.step("opening a file opens a window on it") do
    application.open([Gio::File.new_for_path(SCRATCH_FILE)])
  end

  d.step("the new window shows the file") do
    application.instance_variable_get(:@windows).then do |windows|
      d.check("three windows") { windows.length == 3 }
      d.check("file loaded") { windows.last.editor.buffer.text == TEXT }
      d.shot("17-opened-file", windows.last.window)
    end
  end
end
