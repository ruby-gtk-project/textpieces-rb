# frozen_string_literal: true

require "adwaita"
require_relative "search_bar"
require_relative "translation"

# Editor is the text view, the overlaid argument entries and the toast area.
#
# Ported from upstream's src/widgets/Editor.vala and
# resources/ui/Editor.blp: a toast overlay over an overlay, whose main child
# is the scrolled text view and whose overlay child is the column holding the
# search bar and the argument entries.
#
# Upstream's view is a GtkSource.View, which has no Ruby bindings; this one is
# a Gtk::TextView. The settings upstream binds to GtkSource properties are
# applied here instead: the font through a CSS provider as upstream does,
# wrap-lines through the view's wrap mode, and tabs-to-spaces plus
# spaces-in-tab through a key handler that inserts the right amount of
# whitespace for Tab.
class Editor
  TOAST_TIMEOUT = 2

  def initialize(settings)
    @settings = settings
  end

  def build
    toast_overlay.tap do |overlay|
      overlay.child = editor_overlay

      editor_overlay.tap do |stack|
        stack.child = scroller
        stack.add_overlay(overlay_box)

        scroller.child = view

        overlay_box.tap do |box|
          box.append(search_bar.build)
          box.append(arguments_box)
        end
      end

      view.tap do |text|
        text.add_controller(drop_target)
        text.add_controller(tab_controller)
      end

      install_font_provider

      apply_settings
    end
  end

  def widget = toast_overlay

  def search_bar = @search_bar ||= SearchBar.new(view)

  def grab_focus = view.grab_focus

  def buffer = view.buffer

  # The selection, or the whole text when nothing is selected.
  def selection
    bounds_for_transform.then { |from, to| buffer.get_text(from, to, false) }
  end

  def copy_text
    Gdk::Display.default.clipboard.set(buffer.text)
    show_message(Translation.t("Text is copied"))
  end

  # Replaces the selection, or the whole text when nothing is selected, and
  # leaves the replacement selected so the next tool can be applied to it.
  def replace_selection(text)
    buffer.has_selection?.then do |had_selection|
      bounds_for_transform.then do |from, _|
        from.offset.tap do |start_offset|
          splice(text)
          reselect(start_offset, text, had_selection)
        end
      end
    end
  end

  # Replaces the argument entries with one per argument of the selected tool,
  # and hides the row when the tool takes none.
  def arguments=(arguments)
    clear_arguments
    arguments.each { |argument| arguments_box.append(argument_entry(argument)) }
    arguments_box.visible = !arguments.empty?
  end

  def arguments = argument_entries.map(&:text)

  def jump_to_args
    if arguments_box.visible?
      argument_entries.first&.grab_focus
    end
  end

  def save_as(file)
    File.write(file.path, buffer.text)
  end

  def load_from(file)
    buffer.text = File.read(file.path)
  end

  def show_message(message)
    toast_overlay.add_toast(
      Adwaita::Toast.new(message).tap do |toast|
        toast.priority = :high
        toast.timeout = TOAST_TIMEOUT
      end,
    )
  end

  # Keeps the first line of text clear of the floating argument entries, and
  # keeps the visible line on screen while the margin changes.
  def update_editor_margin
    view.top_margin.then do |old_margin|
      view.top_margin = new_margin
      view.vadjustment.value = [
        view.vadjustment.value - old_margin + view.top_margin,
        0,
      ].max
    end
  end

  # Memoized widget methods

  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
  def editor_overlay = @editor_overlay ||= Gtk::Overlay.new

  def scroller
    @scroller ||= Gtk::ScrolledWindow.new.tap do |window|
      window.vexpand = true
    end
  end

  def view
    @view ||= Gtk::TextView.new.tap do |text|
      text.monospace = true
      text.top_margin = 6
      text.left_margin = 6
      text.right_margin = 6
      text.add_css_class("monospace")
    end
  end

  def overlay_box
    @overlay_box ||= Gtk::Box.new(:vertical, 6).tap do |box|
      box.valign = :start
      box.halign = :end
      box.margin_top = 4
    end
  end

  def arguments_box
    @arguments_box ||= Gtk::Box.new(:vertical, 3).tap do |box|
      box.add_css_class("linked")
      box.add_css_class("editor-overlay")
      box.halign = :end
      box.hexpand = false
      box.width_request = 300
      box.margin_top = 5
      box.margin_bottom = 2
      box.margin_start = 5
      box.margin_end = 10
      box.visible = false
    end
  end

  def font_provider = @font_provider ||= Gtk::CssProvider.new

  # Dropping a file onto the editor loads its contents, as upstream's drop
  # target does.
  def drop_target
    @drop_target ||= Gtk::DropTarget.new(Gio::File.gtype, :copy).tap do |target|
      target.signal_connect("drop") { |_, value, _x, _y| load_dropped(value) }
    end
  end

  # Tab inserts spaces when tabs-to-spaces is on, which is the setting
  # upstream hands to GtkSource.View as insert-spaces-instead-of-tabs.
  def tab_controller
    @tab_controller ||= Gtk::EventControllerKey.new.tap do |controller|
      controller.signal_connect("key-pressed") do |_, keyval, _code, state|
        on_key_pressed(keyval, state)
      end
    end
  end

  private

    # Upstream adds the font provider to the editor's own style context;
    # Gtk::Widget#get_style_context is not bound, so it goes on the display
    # instead. The rule it carries only names .monospace, so the effect is the
    # same.
    def install_font_provider
      Gdk::Display.default.then do |display|
        if display
          Gtk::StyleContext.add_provider_for_display(
            display,
            font_provider,
            Gtk::StyleProvider::PRIORITY_USER,
          )
        end
      end
    end

    def apply_settings
      @settings.subscribe("font-name") { |font| apply_font(font) }
      @settings.subscribe("wrap-lines") { |wrap| apply_wrap(wrap) }
      @settings.subscribe("tabs-to-spaces") { |spaces| @tabs_to_spaces = spaces }
      @settings.subscribe("spaces-in-tab") { |width| @spaces_in_tab = width }
    end

    def apply_font(font)
      if font.to_s.empty?
        font_provider.load_from_string("")
      else
        font_provider.load_from_string(".monospace { font-family: \"#{font}\"; }")
      end
    end

    def apply_wrap(wrap)
      if wrap
        view.wrap_mode = :word_char
      else
        view.wrap_mode = :none
      end
    end

    def on_key_pressed(keyval, state)
      if keyval == Gdk::Keyval::KEY_Tab && @tabs_to_spaces && plain_modifiers?(state)
        buffer.insert_at_cursor(" " * @spaces_in_tab.to_i)
        true
      else
        false
      end
    end

    def plain_modifiers?(state)
      (state.to_i & (Gdk::ModifierType::CONTROL_MASK.to_i |
                     Gdk::ModifierType::ALT_MASK.to_i |
                     Gdk::ModifierType::SHIFT_MASK.to_i)).zero?
    end

    def load_dropped(value)
      buffer.text = File.read(value.path)
      true
    rescue SystemCallError => e
      warn "failed to load file #{value.path}: #{e.message}"
      false
    end

    def bounds_for_transform
      if buffer.has_selection?
        buffer.selection_bounds
      else
        buffer.bounds
      end
    end

    def splice(text)
      buffer.begin_user_action
      bounds_for_transform.then { |from, to| buffer.delete(from, to) }
      buffer.insert_at_cursor(text)
      buffer.end_user_action
    end

    def reselect(start_offset, text, had_selection)
      if had_selection
        buffer.select_range(
          buffer.get_iter_at(offset: start_offset),
          buffer.get_iter_at(offset: start_offset + text.length),
        )
      else
        buffer.place_cursor(buffer.get_iter_at(offset: start_offset))
      end
    end

    def argument_entries
      [].tap do |entries|
        child = arguments_box.first_child
        while child
          entries << child
          child = child.next_sibling
        end
      end
    end

    def clear_arguments
      argument_entries.each { |entry| arguments_box.remove(entry) }
    end

    # Enter in an argument entry moves to the next one, so a tool's arguments
    # can be filled in without reaching for the mouse.
    def argument_entry(argument)
      Gtk::Entry.new.tap do |entry|
        entry.placeholder_text = argument
        entry.add_css_class("monospace")
        entry.signal_connect("activate") { focus_after(entry) }
      end
    end

    # Enter in the last argument entry lands back in the text, which is where
    # upstream's move_focus (TAB_FORWARD) ends up too.
    def focus_after(entry)
      entry.next_sibling.then do |sibling|
        if sibling
          sibling.grab_focus
        else
          view.grab_focus
        end
      end
    end

    # The argument entries float over the first line, so the view's top margin
    # is their measured height. compute_bounds hands back a success flag and
    # the rectangle; an unmapped box has neither.
    def new_margin
      arguments_box.compute_bounds(editor_overlay).then do |ok, bounds|
        if arguments_box.visible? && ok
          bounds.height.ceil
        else
          6
        end
      end
    end
end
