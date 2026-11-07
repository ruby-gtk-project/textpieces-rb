# frozen_string_literal: true

require "adwaita"
require_relative "accelerator"
require_relative "search_context"
require_relative "search_entry"
require_relative "translation"

# SearchBar is the find-and-replace card that slides down over the editor.
#
# Ported from upstream's src/widgets/SearchBar.vala and
# resources/ui/SearchBar.blp: a revealer holding the find entry, the
# previous/next buttons, the replace and options toggles, a close button, the
# replace row and the three search option checkboxes. The "search" action
# group it installs is the same one the template's shortcuts and the main
# window's find action address.
#
# Upstream drives GtkSource.SearchContext and GtkSource.SearchSettings
# directly; this port's SearchContext wraps the same two classes from
# `gtksourceview5` so SearchBar and SearchEntry can stay offset/iterator-light.
class SearchBar
  WINDOW_SHORTCUTS = {
    "<Ctrl>f" => "search.show",
    "<Ctrl>h" => "search.show-replace",
  }.freeze

  REVEALER_SHORTCUTS = {
    "Escape" => "search.hide",
  }.freeze

  def initialize(view)
    @view = view
  end

  def build
    root.tap do |bin|
      bin.child = search_revealer
      bin.insert_action_group("search", action_group)
      bin.add_controller(Accelerator.controller(:managed, WINDOW_SHORTCUTS))

      search_revealer.tap do |revealer|
        revealer.child = grid
        revealer.add_controller(Accelerator.controller(:managed, REVEALER_SHORTCUTS))
        revealer.signal_connect("notify::child-revealed") do
          context.highlight = revealer.child_revealed?
        end
      end

      grid.tap do |layout|
        cells.each do |widget, column, row, span|
          layout.attach(
            widget,
            column,
            row,
            span,
            1,
          )
        end

        match_buttons.tap do |box|
          box.append(prev_button)
          box.append(next_button)
        end

        options_box.tap do |box|
          box.append(regex_check)
          box.append(case_check)
          box.append(words_check)

          regex_check.signal_connect("toggled") { context.regex_enabled = regex_check.active? }
          case_check.signal_connect("toggled") { context.case_sensitive = case_check.active? }
          words_check.signal_connect("toggled") { context.at_word_boundaries = words_check.active? }
        end

        replace_entry.signal_connect("changed") { replace_entry.remove_css_class("error") }

        search_replace.tap do |toggle|
          toggle.bind_property(
            "active",
            replace_entry,
            "visible",
            :sync_create,
          )
          toggle.bind_property(
            "active",
            replace_button,
            "visible",
            :sync_create,
          )
          toggle.bind_property(
            "active",
            replace_all_button,
            "visible",
            :sync_create,
          )
        end

        search_options.bind_property(
          "active",
          options_box,
          "visible",
          :sync_create,
        )
      end

      search_entry.set_context(context)
      context.on_change { update_sensitivity }
    end.tap { update_sensitivity }
  end

  def widget = root

  # Upstream's show_search: a fresh query, the card revealed, the entry
  # focused.
  def show_search
    search_entry.query = ""
    search_revealer.reveal_child = true
    search_entry.grab_focus
  end

  def show_replace
    show_search
    search_replace.active = true
  end

  def hide_search
    search_revealer.reveal_child = false
    search_replace.active = false
    @view.grab_focus
  end

  def next_match
    context.forward(cursor_offset(:end)).then do |match|
      if match
        select(match)
      end
    end
  end

  def prev_match
    context.backward(cursor_offset(:start)).then do |match|
      if match
        select(match)
      end
    end
  end

  # Replaces the selected match. A replacement the engine refuses — a
  # backreference to a group the query does not have — flashes the entry, as
  # upstream's error style and error bell do.
  def replace
    buffer.selection_bounds.then do |bounds|
      if bounds && context.replace(bounds[0], bounds[1], replace_entry.text)
        next_match
      else
        report_replace_error
      end
    end
  end

  def replace_all
    if context.replace_all(replace_entry.text).zero?
      report_replace_error
    end
  end

  def context = @context ||= SearchContext.new(buffer)

  # Memoized widget methods

  def root = @root ||= Adwaita::Bin.new

  def search_revealer
    @search_revealer ||= Gtk::Revealer.new.tap do |revealer|
      revealer.transition_type = :slide_down
    end
  end

  def grid
    @grid ||= Gtk::Grid.new.tap do |layout|
      layout.add_css_class("editor-overlay")
      layout.margin_top = 5
      layout.margin_bottom = 2
      layout.margin_start = 5
      layout.margin_end = 10
      layout.row_spacing = 6
      layout.column_spacing = 6
    end
  end

  def search_entry = @search_entry ||= SearchEntry.new

  def match_buttons
    @match_buttons ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.add_css_class("linked")
      box.homogeneous = true
    end
  end

  def prev_button
    @prev_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = "go-up-symbolic"
      button.tooltip_text = Translation.t("Move to previous match")
      button.action_name = "search.prev-match"
    end
  end

  def next_button
    @next_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = "go-down-symbolic"
      button.tooltip_text = Translation.t("Move to next match")
      button.action_name = "search.next-match"
    end
  end

  def search_replace
    @search_replace ||= Gtk::ToggleButton.new.tap do |toggle|
      toggle.icon_name = "edit-find-replace-symbolic"
      toggle.tooltip_text = Translation.t("Find and replace")
    end
  end

  def search_options
    @search_options ||= Gtk::ToggleButton.new.tap do |toggle|
      toggle.icon_name = "preferences-symbolic"
      toggle.tooltip_text = Translation.t("Toggle search options")
    end
  end

  def close_button
    @close_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = "window-close-symbolic"
      button.tooltip_text = Translation.t("Close search")
      button.action_name = "search.hide"
      button.add_css_class("flat")
      button.add_css_class("circular")
    end
  end

  def replace_entry
    @replace_entry ||= Gtk::Entry.new.tap do |entry|
      entry.primary_icon_name = "edit-find-replace-symbolic"
      entry.primary_icon_activatable = false
      entry.placeholder_text = Translation.t("Replace")
      entry.visible = false
    end
  end

  def replace_button
    @replace_button ||= Gtk::Button.new.tap do |button|
      button.label = Translation.t("_Replace")
      button.use_underline = true
      button.visible = false
      button.action_name = "search.replace"
    end
  end

  def replace_all_button
    @replace_all_button ||= Gtk::Button.new.tap do |button|
      button.label = Translation.t("Replace _All")
      button.use_underline = true
      button.visible = false
      button.action_name = "search.replace-all"
    end
  end

  def options_box
    @options_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.visible = false
    end
  end

  def regex_check = @regex_check ||= option_check("Re_gular expressions")
  def case_check = @case_check ||= option_check("_Case sensitive")
  def words_check = @words_check ||= option_check("Match whole _word only")

  # The grid positions of the template's children: widget, column, row and
  # how many columns it spans.
  def cells
    [
      [search_entry.build, 0, 0, 1],
      [match_buttons, 1, 0, 1],
      [search_replace, 2, 0, 1],
      [search_options, 3, 0, 1],
      [close_button, 4, 0, 1],
      [replace_entry, 0, 1, 1],
      [replace_button, 1, 1, 1],
      [replace_all_button, 2, 1, 3],
      [options_box, 0, 2, 5],
    ]
  end

  def action_group
    @action_group ||= Gio::SimpleActionGroup.new.tap do |group|
      ACTIONS.each do |name, method_name|
        group.add_action(
          Gio::SimpleAction.new(name).tap do |action|
            action.signal_connect("activate") { public_send(method_name) }
          end,
        )
      end
    end
  end

  ACTIONS = {
    "hide"         => :hide_search,
    "show"         => :show_search,
    "show-replace" => :show_replace,
    "next-match"   => :next_match,
    "prev-match"   => :prev_match,
    "replace"      => :replace,
    "replace-all"  => :replace_all,
  }.freeze

  private

    def option_check(label)
      Gtk::CheckButton.new.tap do |check|
        check.label = Translation.t(label)
        check.use_underline = true
      end
    end

    def buffer = @view.buffer

    # Forward search starts at the end of the selection and backward search at
    # its start, so repeated presses walk the matches instead of finding the
    # selected one again.
    def cursor_offset(edge)
      buffer.selection_bounds.then do |bounds|
        if bounds
          [bounds[0].offset, bounds[1].offset].minmax.then do |from, to|
            if edge == :start
              from
            else
              to
            end
          end
        else
          buffer.cursor_position
        end
      end
    end

    def select(match)
      buffer.select_range(
        buffer.get_iter_at(offset: match[0]),
        buffer.get_iter_at(offset: match[1]),
      )
      @view.scroll_mark_onscreen(buffer.get_mark("insert"))
    end

    def report_replace_error
      replace_entry.add_css_class("error")
      replace_entry.error_bell
    end

    # The Replace button needs a match under the cursor and Replace All needs
    # any match at all, which is what the template's sensitive bindings say.
    def update_sensitivity
      replace_button.sensitive = search_entry.occurrence_position.positive?
      replace_all_button.sensitive = context.occurrences_count.positive?
    end
end
