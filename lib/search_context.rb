# frozen_string_literal: true

require "gtk4"

# SearchContext finds, highlights and replaces matches in the editor's buffer.
#
# This is the part of GtkSourceView the port cannot import: upstream's
# SearchBar drives a GtkSource.SearchContext and a GtkSource.SearchSettings,
# and neither has Ruby bindings. The behaviour they give the search bar —
# wrap-around forward and backward search, a highlight tag over every match,
# an occurrences count, the position of the current match, replace and replace
# all, and the regex / case-sensitive / whole-word switches — is implemented
# here over a plain Gtk::TextBuffer.
#
# Matches are recomputed from the buffer text whenever the text or the search
# settings change, and offsets are character offsets, which is what
# Gtk::TextBuffer#get_iter_at_offset expects.
class SearchContext
  HIGHLIGHT_TAG = "textpieces-search-match"

  attr_reader :buffer, :search_text, :occurrences_count

  def initialize(buffer)
    @buffer = buffer
    @search_text = ""
    @regex_enabled = false
    @case_sensitive = false
    @at_word_boundaries = false
    @highlight = false
    @matches = []
    @occurrences_count = 0
    @observers = []
    @buffer.signal_connect("changed") { recompute }
    recompute
  end

  def on_change(&block)
    @observers << block
    block
  end

  def search_text=(value)
    @search_text = value.to_s
    recompute
  end

  def regex_enabled=(value)
    @regex_enabled = value
    recompute
  end

  def case_sensitive=(value)
    @case_sensitive = value
    recompute
  end

  def at_word_boundaries=(value)
    @at_word_boundaries = value
    recompute
  end

  # Upstream binds the revealer's child-revealed to the context's highlight
  # property, so the matches light up only while the bar is open.
  def highlight=(value)
    @highlight = value
    apply_highlight
  end

  def highlight? = @highlight

  # True when the query is a regular expression the engine refused. Upstream's
  # search settings carry the same condition as a regex_error.
  def regex_error? = @regex_error

  # The 1-based position of the match the given range covers, or 0 when the
  # range is not a match — upstream's get_occurrence_position.
  def occurrence_position(start_iter, end_iter)
    [start_iter.offset, end_iter.offset].minmax.then do |from, to|
      @matches.index([from, to]).then do |index|
        if index
          index + 1
        else
          0
        end
      end
    end
  end

  # The first match at or after the offset, wrapping around to the top.
  def forward(offset)
    @matches.find { |from, _| from >= offset } || @matches.first
  end

  # The last match that ends at or before the offset, wrapping to the bottom.
  def backward(offset)
    @matches.reverse.find { |_, to| to <= offset } || @matches.last
  end

  # Replaces one match, named by the range the editor has selected. Returns
  # false when that range is not a match, which is what upstream's `requires
  # (occurrence_position > 0)` precondition guards against.
  def replace(start_iter, end_iter, replacement)
    [start_iter.offset, end_iter.offset].minmax.then do |from, to|
      if @matches.include?([from, to])
        replace_range(from, to, replacement_for(from, to, replacement))
        true
      else
        false
      end
    end
  end

  # Replaces every match, last first so the earlier offsets stay valid.
  def replace_all(replacement)
    @matches.length.tap do
      @matches.reverse.each do |from, to|
        replace_range(from, to, replacement_for(from, to, replacement))
      end
    end
  end

  private

    def notify
      @observers.each { |block| block.call(self) }
    end

    def recompute
      @matches = compute_matches
      @occurrences_count = @matches.length
      apply_highlight
      notify
    end

    def compute_matches
      pattern.then do |regexp|
        if regexp.nil? || @search_text.empty?
          []
        else
          @buffer.text.to_enum(:scan, regexp).map { Regexp.last_match }
                 .map { |match| [match.begin(0), match.end(0)] }
                 .reject { |from, to| from == to }
        end
      end
    end

    # The search settings, as one regular expression: the literal query is
    # escaped, word boundaries become \b, and case sensitivity is a flag.
    def pattern
      @regex_error = false
      if @search_text.empty?
        nil
      else
        Regexp.new(bounded(source), flags)
      end
    rescue RegexpError
      @regex_error = true
      nil
    end

    def source
      if @regex_enabled
        @search_text
      else
        Regexp.escape(@search_text)
      end
    end

    def bounded(source)
      if @at_word_boundaries
        "\\b(?:#{source})\\b"
      else
        source
      end
    end

    def flags
      if @case_sensitive
        Regexp::MULTILINE
      else
        Regexp::MULTILINE | Regexp::IGNORECASE
      end
    end

    # A regex replacement keeps its backreferences, as upstream's
    # GtkSource.SearchContext.replace does; a literal one is inserted as typed.
    def replacement_for(from, to, replacement)
      if @regex_enabled && pattern
        @buffer.text[from...to].sub(pattern, replacement)
      else
        replacement
      end
    end

    def replace_range(from, to, text)
      @buffer.begin_user_action
      @buffer.delete(@buffer.get_iter_at(offset: from), @buffer.get_iter_at(offset: to))
      @buffer.insert(@buffer.get_iter_at(offset: from), text)
      @buffer.end_user_action
    end

    def apply_highlight
      @buffer.remove_tag(highlight_tag, *@buffer.bounds)
      if @highlight
        @matches.each do |from, to|
          @buffer.apply_tag(
            highlight_tag,
            @buffer.get_iter_at(offset: from),
            @buffer.get_iter_at(offset: to),
          )
        end
      end
    end

    def highlight_tag
      @highlight_tag ||= @buffer.tag_table.lookup(HIGHLIGHT_TAG) ||
                         @buffer.create_tag(HIGHLIGHT_TAG, background: "#f9e07f", foreground: "#1d1d1d")
    end
end
