# frozen_string_literal: true

require "adwaita"
require_relative "tool"
require_relative "tool_row"
require_relative "translation"

# Search is the tool chooser: a search entry's query, filtered and sorted
# against every tool, listed as rows.
#
# Ported from upstream's src/widgets/Search.vala and
# resources/ui/Search.blp: a stack whose "search" page is the clamped,
# boxed-list of results and whose "placeholder" page is the "No Tools Found"
# status page with its "Add Custom Tool" button. The relevance algorithm —
# query split into terms, each term looked for in the tool's name and then its
# description, the distance to each match summed into an irrelevance score,
# with an untranslated and a translated pass and the better of the two kept —
# is a direct port of calculate_irrelevance and friends.
#
# Upstream feeds that algorithm to a Gtk.CustomFilter and a Gtk.CustomSorter
# stacked over the tools model. The Ruby bindings hand a custom sorter's
# callback a pair of integers rather than the two objects being compared, so
# the scored, sorted list is built in Ruby and spliced into the store the list
# box is bound to — which is also how the rows get rebuilt when a custom tool
# is added or deleted.
class Search
  # Upstream's int.MAX: the score of a tool that does not match at all, which
  # the filter drops.
  IRRELEVANT = (2**31) - 1

  LIST_MARGIN = 24
  CLAMP_SIZE = 600

  # The tools the current query matches, in the order they are listed. This,
  # not the list store, is what a reader should go through.
  attr_reader :results

  def initialize(tools, search_entry, on_tool_selected: nil)
    @tools = tools
    @search_entry = search_entry
    @on_tool_selected = on_tool_selected
    @results = []
  end

  def build
    stack.tap do |pages|
      pages.add_named(scroller, "search")
      pages.add_named(placeholder_page, "placeholder")

      scroller.child = viewport

      viewport.tap do |port|
        port.child = clamp
        clamp.child = results_listbox

        results_listbox.tap do |list|
          list.bind_model(results_store) { |tool| ToolRow.build(tool) }
          list.signal_connect("row-activated") { |_, row| on_row_activated(row) }
        end
      end

      placeholder_page.child = add_tool_button

      @search_entry.tap do |entry|
        entry.signal_connect("changed") { update_search_results }
        entry.signal_connect("activate") { activate_selected_result }
        entry.add_controller(key_controller)
      end

      @tools.all_tools.signal_connect("items-changed") { update_search_results }
    end.tap { update_search_results }
  end

  def widget = stack

  # Upstream's reset: clear the query, scroll to the top, select the first row.
  def reset
    @search_entry.text = ""
    viewport.vadjustment.value = 0
    results_listbox.select_row(results_listbox.get_row_at_index(0))
  end

  # Memoized widget methods

  def stack
    @stack ||= Gtk::Stack.new.tap do |pages|
      pages.transition_type = :crossfade
    end
  end

  def scroller = @scroller ||= Gtk::ScrolledWindow.new

  def viewport
    @viewport ||= Gtk::Viewport.new(nil, nil).tap do |port|
      port.scroll_to_focus = true
    end
  end

  def clamp
    @clamp ||= Adwaita::Clamp.new.tap do |widget|
      widget.maximum_size = CLAMP_SIZE
    end
  end

  def results_listbox
    @results_listbox ||= Gtk::ListBox.new.tap do |list|
      list.add_css_class("boxed-list")
      list.margin_top = LIST_MARGIN
      list.margin_bottom = LIST_MARGIN
      list.valign = :start
      list.selection_mode = :browse
    end
  end

  def placeholder_page
    @placeholder_page ||= Adwaita::StatusPage.new.tap do |page|
      page.icon_name = "applications-utilities-symbolic"
      page.title = Translation.t("No Tools Found")
    end
  end

  def add_tool_button
    @add_tool_button ||= Gtk::Button.new.tap do |button|
      button.add_css_class("flat")
      button.halign = :center
      button.action_name = "win.tools-settings"
      button.child = Adwaita::ButtonContent.new.tap do |content|
        content.icon_name = "list-add-symbolic"
        content.label = Translation.t("_Add Custom Tool")
        content.use_underline = true
      end
    end
  end

  def results_store = @results_store ||= Gio::ListStore.new(Tool)

  def key_controller
    @key_controller ||= Gtk::EventControllerKey.new.tap do |controller|
      controller.signal_connect("key-pressed") { |_, keyval, _code, _state| on_key(keyval) }
    end
  end

  private

    def query = @search_entry.text.to_s

    # Upstream's tool_filter_func and tool_sort_func: tools that do not match
    # at all are dropped, less relevant tools sort lower, and tools of equal
    # relevance sort by name — which is also what an empty query gives.
    def scored_results
      @tools.all
            .map { |tool| [irrelevance(tool), tool] }
            .reject { |score, _| score == IRRELEVANT }
            .sort_by { |score, tool| [score, tool.translated_name] }
            .map { |_, tool| tool }
    end

    def irrelevance(tool)
      query.downcase.then do |casefolded|
        [
          irrelevance_for_fields([tool.name.downcase, tool.description.downcase], casefolded),
          irrelevance_for_fields(
            [tool.translated_name.downcase, tool.translated_description.downcase],
            casefolded,
          ),
        ].min
      end
    end

    # The algorithm, verbatim from upstream: walk the terms, find each one in
    # the first field that still contains it after the part already matched,
    # add the distance from where that field was cut to the match, and cut the
    # field again. A term that is nowhere makes the tool irrelevant. Finally
    # add the lengths of the leading fields nothing matched in, so a
    # description match sorts below a name match.
    def irrelevance_for_fields(fields, query)
      if query.empty?
        0
      else
        score_terms(fields, query.split(" "))
      end
    end

    def score_terms(fields, terms)
      beginnings = Array.new(fields.length, 0)
      irrelevance = 0

      terms.each do |term|
        match = first_match(fields, beginnings, term)
        if match.nil?
          irrelevance = IRRELEVANT
          break
        end
        field, offset = match
        irrelevance += offset - beginnings[field]
        beginnings[field] = offset + term.length
      end

      if irrelevance == IRRELEVANT
        IRRELEVANT
      else
        irrelevance + unmatched_prefix(fields, beginnings)
      end
    end

    # The first field, in order, that still contains the term past the point
    # already matched, as [field index, offset].
    def first_match(fields, beginnings, term)
      fields.each_index
            .filter_map { |field| offset_in(
              fields,
              beginnings,
              field,
              term,
            ) }
            .first
    end

    def offset_in(fields, beginnings, field, term)
      fields[field].index(term, beginnings[field])&.then { |offset| [field, offset] }
    end

    def unmatched_prefix(fields, beginnings)
      fields.each_index
            .take_while { |field| beginnings[field].zero? }
            .sum { |field| fields[field].length }
    end

    def update_search_results
      scored_results.then do |tools|
        @results = tools
        results_store.splice(0, results_store.n_items, tools)
      end

      if results_listbox.selected_row.nil?
        results_listbox.select_row(results_listbox.get_row_at_index(0))
      end

      update_placeholder
    end

    def update_placeholder
      if @results.empty?
        stack.visible_child_name = "placeholder"
      else
        stack.visible_child_name = "search"
      end
    end

    def activate_selected_result
      (results_listbox.selected_row || results_listbox.get_row_at_index(0)).then do |row|
        if row
          results_listbox.signal_emit("row-activated", row)
        end
      end
    end

    # Read from the Ruby-side list, never back out of the store: a tool a
    # splice has dropped can come back as a wrapper over freed memory.
    def on_row_activated(row)
      @results[row.index].then do |tool|
        if tool
          @on_tool_selected&.call(tool)
        end
      end
    end

    # Up and Down in the search entry move the selection in the results,
    # which is what upstream achieves by forwarding the key event to the list
    # box and taking focus back afterwards.
    def on_key(keyval)
      case keyval
      when Gdk::Keyval::KEY_Down
        move_selection(1)
      when Gdk::Keyval::KEY_Up
        move_selection(-1)
      else
        false
      end
    end

    def move_selection(step)
      selected_index.then do |index|
        results_listbox.get_row_at_index(index + step).then do |row|
          if row
            results_listbox.select_row(row)
            viewport.vadjustment.then { scroll_to(row) }
          end
        end
      end
      true
    end

    def selected_index
      results_listbox.selected_row.then do |row|
        if row
          row.index
        else
          -1
        end
      end
    end

    def scroll_to(row)
      row.compute_bounds(viewport).then do |ok, bounds|
        if ok
          viewport.vadjustment.value = bounds.y + viewport.vadjustment.value
        end
      end
    end
end
