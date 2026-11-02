# frozen_string_literal: true

require "json"

# StyleScheme is a set of editor colours: an id, a display name, the named
# styles the editor paints with, and the metadata Recoloring reads.
#
# Upstream gets these from GtkSourceView, whose StyleSchemeManager loads the
# schemes and whose StyleSchemeChooserWidget lets the user pick one.
# GtkSourceView has no Ruby bindings, so this class is the part of
# GtkSource.StyleScheme that upstream's Recoloring actually asks for — #id,
# #style and #metadata_value — and the schemes themselves are shipped with the
# port, in data/style-schemes, one JSON file each.
#
# The two Adwaita schemes carry the palette of the stock Adwaita stylesheet,
# which is why Recoloring leaves them alone; the others are recoloured from
# their text and selection styles, which is the whole point of the mechanism.
class StyleScheme
  SCHEME_DIR = File.expand_path("../data/style-schemes", __dir__)
  DEFAULT_ID = "Adwaita-dark"

  Style = Data.define(:foreground, :background)

  attr_reader :id, :name, :description, :styles, :metadata

  def initialize(id:, name:, styles:, metadata: {}, description: nil)
    @id = id
    @name = name
    @description = description
    @styles = styles
    @metadata = metadata
  end

  # Upstream's scheme.get_style (name): nil when the scheme says nothing about
  # that style, which is what makes Recoloring fall back.
  def style(name) = @styles[name.to_s]

  # Upstream's scheme.get_metadata (key).
  def metadata_value(key) = @metadata[key.to_s]

  class << self
    def all
      @all ||= Dir.glob(File.join(SCHEME_DIR, "*.json"))
                  .sort
                  .filter_map { |path| load_file(path) }
                  .sort_by(&:name)
    end

    def find(id) = all.find { |scheme| scheme.id == id }

    # The scheme the settings name, falling back to the default and then to
    # whatever is installed, so a settings file naming a scheme this install
    # does not have still starts.
    def find_or_default(id) = find(id) || find(DEFAULT_ID) || all.first

    def load_file(path)
      build(JSON.parse(File.read(path)))
    rescue JSON::ParserError, SystemCallError
      nil
    end

    private

      def build(data)
        new(
          id:          data["id"].to_s,
          name:        data.fetch("name", data["id"]).to_s,
          description: data["description"],
          metadata:    data.fetch("metadata", {}),
          styles:      styles_of(data.fetch("styles", {})),
        )
      end

      # A missing key is a colour the scheme does not set, which is the
      # foreground_set / background_set pair upstream checks.
      def styles_of(styles)
        styles.transform_values do |style|
          Style.new(
            foreground: style["foreground"],
            background: style["background"],
          )
        end
      end
  end
end
