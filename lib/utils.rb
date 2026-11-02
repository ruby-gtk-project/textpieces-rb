# frozen_string_literal: true

require "fileutils"

# Utils holds the small filesystem helpers the rest of the port needs.
#
# Ported from upstream's src/utils/Utils.vala, which has a single
# `ensure_directory_exists` recursing up the parents before creating the
# directory itself. Ruby's FileUtils.mkdir_p already walks the parents, so the
# recursion collapses into one call; the behaviour — create it if it is not
# there, do nothing if it is — is the same.
module Utils
  class << self
    def ensure_directory_exists(path)
      path.to_s.tap do |dir|
        FileUtils.mkdir_p(dir)
      end
    end

    # Upstream passes tool stderr through GLib's Markup.escape_text before it
    # reaches a toast, because Adw.Toast titles are Pango markup.
    def escape_markup(text)
      text.to_s
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
          .gsub("'", "&apos;")
          .gsub('"', "&quot;")
    end
  end
end
