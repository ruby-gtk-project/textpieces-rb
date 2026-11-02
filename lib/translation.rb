# frozen_string_literal: true

# Translation looks up UI strings and tool metadata in the port's gettext
# catalogs.
#
# Ported from po/ — upstream's po/textpieces.pot, po/tools.pot and the es, nl
# and pt_BR catalogs, which are shipped here unchanged. Upstream reaches them
# through Intl.textdomain plus _() and dpgettext2 (null, "tools", …); the Ruby
# gettext gem is not a runtime dependency of this port, so the catalogs are
# parsed directly. Both halves of the upstream domain live in one .po file:
# interface msgids with no context, and tool names, descriptions and argument
# labels under the "tools" context.
module Translation
  PO_DIR = File.expand_path("../po", __dir__)
  TOOLS_CONTEXT = "tools"

  ESCAPES = {
    "n"  => "\n",
    "t"  => "\t",
    "r"  => "\r",
    '"'  => '"',
    "\\" => "\\",
  }.freeze

  class << self
    # The msgid is returned untranslated when the catalog has no entry for it,
    # which is what gettext does and what keeps the English strings working
    # with no catalog installed at all.
    def t(msgid, context: nil)
      catalog.fetch([context, msgid.to_s], msgid.to_s)
    end

    # Upstream's dpgettext2 (null, "tools", …) calls, used for everything that
    # comes out of tools.json.
    def tools(msgid) = t(msgid, context: TOOLS_CONTEXT)

    def catalog = @catalog ||= load_catalog(language)

    # Re-reads the catalog for a given language. Exposed so a test can ask for
    # a locale the ambient environment does not have.
    def use_language(language)
      @language = language
      @catalog = load_catalog(language)
    end

    def language
      @language ||= detect_language
    end

    private

      # The first of the LC_ALL / LC_MESSAGES / LANG trio that is set wins,
      # exactly as in gettext, and the codeset and modifier suffixes are
      # dropped: "pt_BR.UTF-8" names the pt_BR catalog.
      def detect_language
        ENV.values_at("LC_ALL", "LC_MESSAGES", "LANG")
           .compact
           .reject(&:empty?)
           .first
           .to_s
           .split(/[.@]/)
           .first
           .to_s
      end

      # "pt_BR" is tried as "pt_BR" and then as "pt", so a catalog for the
      # bare language still applies to a regional locale.
      def load_catalog(language)
        candidates(language).map { |name| File.join(PO_DIR, "#{name}.po") }
                            .find { |path| File.file?(path) }
                            .then do |path|
          if path
            parse(File.read(path, encoding: "UTF-8"))
          else
            {}
          end
        end
      end

      def candidates(language)
        language.to_s.split("_").then do |parts|
          if parts.length > 1
            [language, parts.first]
          else
            [language].reject { |name| name.empty? || name == "C" || name == "POSIX" }
          end
        end
      end

      # A minimal .po reader: it understands msgctxt, msgid, msgstr and the
      # continuation lines all three can be split across, which is everything
      # the shipped catalogs use. Fuzzy and obsolete entries are comments, so
      # they are skipped along with the rest.
      def parse(source)
        {}.tap do |entries|
          entry = new_entry
          field = nil

          source.each_line do |line|
            stripped = line.strip

            case stripped
            when /\A#/, ""
              nil
            when /\Amsgctxt\s+"(.*)"\z/
              store(entries, entry)
              entry = new_entry
              field = :context
              entry[:context] = unescape(Regexp.last_match(1))
            when /\Amsgid\s+"(.*)"\z/
              if field == :msgstr
                store(entries, entry)
                entry = new_entry
              end
              field = :msgid
              entry[:msgid] = unescape(Regexp.last_match(1))
            when /\Amsgid_plural\s+"(.*)"\z/
              field = :ignored
            when /\Amsgstr(?:\[\d+\])?\s+"(.*)"\z/
              if field == :ignored
                field = :ignored
              else
                field = :msgstr
                entry[:msgstr] = unescape(Regexp.last_match(1))
              end
            when /\A"(.*)"\z/
              continue(entry, field, unescape(Regexp.last_match(1)))
            end
          end

          store(entries, entry)
        end
      end

      def new_entry = { context: nil, msgid: nil, msgstr: nil }

      def continue(entry, field, text)
        case field
        when :context
          entry[:context] = "#{entry[:context]}#{text}"
        when :msgid
          entry[:msgid] = "#{entry[:msgid]}#{text}"
        when :msgstr
          entry[:msgstr] = "#{entry[:msgstr]}#{text}"
        end
      end

      # The header entry has an empty msgid and untranslated entries have an
      # empty msgstr; neither belongs in the lookup table.
      def store(entries, entry)
        if entry[:msgid].to_s != "" && entry[:msgstr].to_s != ""
          entries[[entry[:context], entry[:msgid]]] = entry[:msgstr]
        end
      end

      def unescape(text)
        text.gsub(/\\(.)/) { ESCAPES.fetch(Regexp.last_match(1), Regexp.last_match(1)) }
      end
  end
end
