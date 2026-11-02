# frozen_string_literal: true

require "json"
require_relative "utils"

# Settings holds the keys of upstream's GSettings schema.
#
# Ported from data/com.github.liferooter.textpieces.gschema.xml: the same keys,
# the same defaults, the same meanings. Upstream reads them through
# GLib.Settings, which needs a schema compiled into the system's
# glib-2.0/schemas directory; requiring an install step before the app can run
# from a checkout is worse than the alternative, so the values are stored in a
# small JSON file under XDG_CONFIG_HOME instead.
#
# Upstream also leans on GSettings' bind() and create_action() to keep widgets
# and settings in step. Those become #subscribe here: a writer notifies every
# block registered for the key it changed.
class Settings
  DEFAULTS = {
    "style-scheme"   => "Adwaita-dark",
    "font-name"      => "Monospace",
    "wrap-lines"     => true,
    "tabs-to-spaces" => false,
    "spaces-in-tab"  => 4,
    "window-width"   => 800,
    "window-height"  => 500,
    "is-maximized"   => false,
    "selected-tool"  => "",
  }.freeze

  def initialize(path: nil)
    @path = path || default_path
    @values = DEFAULTS.merge(read)
    @observers = {}
  end

  def location = @path

  def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

  def []=(key, value)
    @values[key.to_s] = value
    write
    notify(key.to_s, value)
    value
  end

  # Registers a block to run whenever the key is written, and runs it once with
  # the current value so a freshly built widget starts in the stored state.
  # This is upstream's `settings.bind (key, widget, property, GET)`.
  def subscribe(key, &block)
    (@observers[key.to_s] ||= []) << block
    block.call(self[key])
    block
  end

  # Named accessors, so callers do not repeat the string keys.
  DEFAULTS.each_key do |key|
    method_name = key.tr("-", "_")
    define_method(method_name) { self[key] }
    define_method(:"#{method_name}=") { |value| self[key] = value }
    if DEFAULTS[key].is_a?(TrueClass) || DEFAULTS[key].is_a?(FalseClass)
      define_method(:"#{method_name}?") { self[key] == true }
    end
  end

  # Upstream's Window.save_window_size, called from both the close request and
  # the application's shutdown handler.
  def save_window_size(window)
    self["window-width"] = window.default_width
    self["window-height"] = window.default_height
    self["is-maximized"] = window.maximized?
  end

  def apply_to(window)
    window.set_default_size(self["window-width"], self["window-height"])
    if self["is-maximized"]
      window.maximize
    end
  end

  private

    def notify(key, value)
      @observers.fetch(key, []).each { |block| block.call(value) }
    end

    def default_path
      ENV.fetch("XDG_CONFIG_HOME", File.join(Dir.home, ".config"))
         .then { |dir| File.join(dir, "textpieces", "settings.json") }
    end

    def read
      if File.file?(@path)
        parse(File.read(@path))
      else
        {}
      end
    end

    def parse(source)
      JSON.parse(source).select { |key, _| DEFAULTS.key?(key) }
    rescue JSON::ParserError
      {}
    end

    def write
      Utils.ensure_directory_exists(File.dirname(@path))
      File.write(@path, "#{JSON.pretty_generate(@values)}\n")
    end
end
