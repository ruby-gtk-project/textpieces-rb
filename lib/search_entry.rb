# frozen_string_literal: true

require "adwaita"
require_relative "translation"
require_relative "accelerator"

# SearchEntry is the find entry of the editor's search bar: a magnifier icon,
# the query text, and the "3 of 11" occurrences label on the right.
#
# Ported from upstream's src/widgets/SearchEntry.vala and
# resources/ui/SearchEntry.blp. Upstream subclasses Gtk.Widget with a
# BoxLayout and the "entry" CSS name so the three children look like one
# entry; here the root is a Gtk::Box carrying the entry style class, which
# gets the same look without a custom widget type.
#
# Return and <Shift>Return activate the next and previous match through the
# search action group, exactly as the upstream template's ShortcutController
# does.
class SearchEntry
  PLACEHOLDER = "Find"
  WIDTH_CHARS = 12

  SHORTCUTS = {
    "Return"        => "search.next-match",
    "<Shift>Return" => "search.prev-match",
  }.freeze

  attr_reader :occurrences_count, :occurrence_position

  def initialize
    @occurrences_count = 0
    @occurrence_position = 0
    @query_observers = []
  end

  def build
    root.tap do |box|
      box.append(icon)
      box.append(text)
      box.append(info_label)

      text.tap do |entry|
        entry.add_controller(shortcut_controller)
        entry.signal_connect("changed") { notify_query }
      end
    end.tap { update_info }
  end

  def widget = root

  def query = text.text

  def query=(value)
    text.text = value.to_s
  end

  def on_query_changed(&block)
    @query_observers << block
    block
  end

  def grab_focus = text.grab_focus

  # Upstream's set_context: the entry watches the search context for the
  # numbers it displays, and the context watches the entry for the query.
  def set_context(context)
    context.on_change { update_from(context) }
    @buffer_handler ||= context.buffer.signal_connect("notify::cursor-position") do
      update_from(context)
    end
    on_query_changed { |query| context.search_text = query }
    context.search_text = query
    update_from(context)
  end

  def occurrences_count=(value)
    @occurrences_count = value.to_i
    update_info
  end

  def occurrence_position=(value)
    @occurrence_position = value.to_i
    update_info
  end

  # Upstream's update_info: nothing at all while there are no matches.
  def update_info
    if @occurrences_count.zero?
      info_label.label = ""
    else
      info_label.label = format(Translation.t("%u of %d"), @occurrence_position, @occurrences_count)
    end
  end

  # Memoized widget methods

  def root
    @root ||= Gtk::Box.new(:horizontal, 6).tap do |box|
      box.width_request = 300
      box.add_css_class("entry")
    end
  end

  def icon = @icon ||= Gtk::Image.new(icon_name: "edit-find-symbolic")

  def text
    @text ||= Gtk::Text.new.tap do |entry|
      entry.placeholder_text = Translation.t(PLACEHOLDER)
      entry.hexpand = true
      entry.vexpand = true
      entry.width_chars = WIDTH_CHARS
      entry.max_width_chars = WIDTH_CHARS
    end
  end

  def info_label
    @info_label ||= Gtk::Label.new.tap do |label|
      label.xalign = 1
      label.opacity = 0.3
    end
  end

  def shortcut_controller
    @shortcut_controller ||= Accelerator.controller(:local, SHORTCUTS)
  end

  private

    def notify_query
      @query_observers.each { |block| block.call(query) }
    end

    def update_from(context)
      @occurrences_count = context.occurrences_count
      @occurrence_position = position_in(context)
      update_info
    end

    def position_in(context)
      context.buffer.selection_bounds.then do |bounds|
        if bounds
          context.occurrence_position(bounds[0], bounds[1])
        else
          0
        end
      end
    end
end
