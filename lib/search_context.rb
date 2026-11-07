# frozen_string_literal: true

require "gtksourceview5"

# SearchContext wraps GtkSource::SearchContext and GtkSource::SearchSettings,
# the pair upstream's SearchBar drives directly (src/widgets/SearchBar.vala's
# `search_context` and `search_settings` fields): wrap-around forward/backward
# search, a highlight toggle bound to the revealer, the occurrences count, the
# 1-based position of a given range, replace and replace-all, and the
# regex / case-sensitive / whole-word switches that live on the settings.
#
# An earlier version of this file reimplemented all of that over a plain
# Gtk::TextBuffer, on the claim that GtkSourceView has no Ruby bindings — false;
# `gtksourceview5` ships both classes, so this is now a thin adapter onto them,
# kept only so SearchBar and SearchEntry do not have to address
# GtkSource::SearchContext's iterator-based API directly.
class SearchContext
  attr_reader :buffer

  def initialize(buffer)
    @buffer = buffer
    @settings = GtkSource::SearchSettings.new.tap { |settings| settings.wrap_around = true }
    @context = GtkSource::SearchContext.new(buffer, @settings)
    @observers = []
    @context.signal_connect("notify::occurrences-count") { notify }
  end

  def on_change(&block)
    @observers << block
    block
  end

  def search_text=(value)
    @settings.search_text = value.to_s
  end

  def regex_enabled=(value)
    @settings.regex_enabled = value
  end

  def case_sensitive=(value)
    @settings.case_sensitive = value
  end

  def at_word_boundaries=(value)
    @settings.at_word_boundaries = value
  end

  # Upstream binds the revealer's child-revealed to the context's highlight
  # property, so the matches light up only while the bar is open.
  def highlight=(value)
    @context.highlight = value
  end

  def highlight? = @context.highlight?

  # -1 means "not computed yet" (the recompute is asynchronous); nothing in
  # this app's lifecycle reads the count before the next main-loop turn
  # settles it, but a defensive floor keeps a stray read honest.
  def occurrences_count = [@context.occurrences_count, 0].max

  # The 1-based position of the match the given range covers, or 0 when the
  # range is not a match — upstream's get_occurrence_position.
  def occurrence_position(start_iter, end_iter)
    @context.get_occurrence_position(start_iter, end_iter)
  end

  # The first match at or after the offset, wrapping around to the top.
  def forward(offset) = iter_match(@context.forward(@buffer.get_iter_at(offset: offset)))

  # The last match that ends at or before the offset, wrapping to the bottom.
  def backward(offset) = iter_match(@context.backward(@buffer.get_iter_at(offset: offset)))

  # Replaces one match, named by the range the editor has selected. False
  # when that range is not an actual match (upstream's `requires
  # (occurrence_position > 0)` precondition) or the engine refuses the
  # replacement (a backreference the query does not have).
  def replace(start_iter, end_iter, replacement)
    @context.replace(start_iter, end_iter, replacement, -1)
  rescue GLib::Error
    false
  end

  # Replaces every match. The count replaced, so SearchBar#replace_all can
  # tell "nothing to replace" from "replaced everything".
  def replace_all(replacement)
    @context.replace_all(replacement, -1)
  rescue GLib::Error
    0
  end

  private

    def notify
      @observers.each { |block| block.call(self) }
    end

    def iter_match(result)
      found, start_iter, end_iter, = result
      if found
        [start_iter.offset, end_iter.offset]
      end
    end
end
