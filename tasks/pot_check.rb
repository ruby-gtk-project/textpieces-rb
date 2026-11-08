# frozen_string_literal: true

# Backs the `rake pot` task.
#
# There is no `rxgettext`/meson `i18n.gettext()` step in this port (it has no
# C extension and no build system to drive one) — `lib/translation.rb` reads
# `po/*.po` directly instead of going through GNU gettext at runtime. That
# means nothing mechanically keeps `po/textpieces.pot` in sync with the
# `Translation.t(...)` / `Translation.tools(...)` call sites in `lib/` and
# `exe/`: a literal added to the source without also being added to the pot
# silently falls back to its English text forever (`Translation.t`'s
# documented miss behaviour) with nothing ever flagging the gap. Two such
# strings were previously found only by manual, file-by-file reading.
#
# This walks the same call sites gettext extraction would, and fails the
# build the way `xgettext --language=Ruby` failing on `rxgettext` not being
# installed never actually did here (see flake.nix's comment on why that
# tool isn't used). It is deliberately narrow: only the two call shapes this
# port actually uses, since those are the only markers `lib/translation.rb`
# ever looks up.
module PotCheck
  LIB_AND_EXE_GLOBS = ["lib/**/*.rb", "exe/*"].freeze

  # A literal single- or double-quoted Ruby string with no interpolation.
  # `Translation.t`/`Translation.tools` are never called with anything else
  # in this codebase (a call built from a runtime value couldn't be matched
  # against a catalogue anyway, the same limit `xgettext` itself has).
  STRING_LIT = /"((?:\\.|[^"\\])*)"|'((?:\\.|[^'\\])*)'/

  CALL = /Translation\.(t|tools)\(\s*#{STRING_LIT}/

  POT_PATH = File.expand_path("../po/textpieces.pot", __dir__)

  # Returns [[context_or_nil, msgid], ...] for every Translation.t/.tools
  # call site found under lib/ and exe/.
  def self.call_sites
    Dir.chdir(File.expand_path("..", __dir__)) do
      LIB_AND_EXE_GLOBS.flat_map { |glob| Dir.glob(glob) }
                       .select { |path| File.file?(path) }
                       .flat_map { |path| call_sites_in(path) }
    end
  end

  def self.call_sites_in(path)
    File.readlines(path, encoding: "UTF-8").each_with_index.filter_map do |line, index|
      match = CALL.match(line)
      next unless match

      method = match[1]
      literal = unescape(match[2] || match[3])
      context = method == "tools" ? "tools" : nil
      [context, literal, "#{path}:#{index + 1}"]
    end
  end

  def self.unescape(text)
    text.gsub(/\\(.)/) { Regexp.last_match(1) == "n" ? "\n" : Regexp.last_match(1) }
  end

  # Returns the set of [context_or_nil, msgid] pairs the pot already has.
  #
  # A minimal .pot reader, mirroring Translation.parse's state machine
  # (msgctxt and msgid may each continue across several quoted lines).
  def self.pot_keys
    source = File.read(POT_PATH, encoding: "UTF-8")
    entries = []
    context = nil
    msgid = nil
    field = nil

    flush = lambda do
      entries << [context, msgid] if msgid && !msgid.empty?
      context = nil
      msgid = nil
    end

    source.each_line do |raw|
      line = raw.strip
      case line
      when /\A#/, ""
        nil
      when /\Amsgctxt\s+"(.*)"\z/
        flush.call
        field = :context
        context = unescape(Regexp.last_match(1))
      when /\Amsgid\s+"(.*)"\z/
        flush.call unless field == :context
        field = :msgid
        msgid = +unescape(Regexp.last_match(1))
      when /\A"(.*)"\z/
        text = unescape(Regexp.last_match(1))
        if field == :context
          context = "#{context}#{text}"
        elsif field == :msgid
          msgid << text
        end
      else
        field = nil
      end
    end
    flush.call

    entries.to_set
  end

  # Returns the call sites with no matching (context, msgid) pot entry.
  def self.missing
    require "set"
    known = pot_keys
    call_sites.reject { |context, msgid, _location| known.include?([context, msgid]) }
  end
end
