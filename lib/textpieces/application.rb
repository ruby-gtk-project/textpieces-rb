# frozen_string_literal: true

require "gtk4"
require "adwaita"
require "gtksourceview5"

require_relative "../recoloring"
require_relative "../settings"
require_relative "../style"
require_relative "../tools_controller"
require_relative "../window"

module Textpieces
  # Application is the application object: one process, any number of windows.
  #
  # Ported from upstream's src/Application.vala — its ACTIONS and
  # ACTION_ACCELS tables, the startup work (stylesheet, icons, accelerators,
  # tool loading), activate opening a window, open loading each file into a
  # window of its own, and shutdown saving the window geometry.
  #
  # The settings object and the tools controller are upstream's static
  # Application.settings and Application.tools; here they are instance state
  # handed to each window, which keeps a test free to build an application
  # over its own settings file.
  #
  # House style (see .claude/skills/ruby-gtk): every widget is a memoized
  # method, all configuration lives in its `tap`, assembly happens only in
  # `build`, and the launcher is one expression.
  class Application
    APP_ID = "org.rubygtkproject.Textpieces"
    ICON_DIR = File.expand_path("../../data/icons", __dir__)

    # Application actions, as upstream's ACTIONS.
    ACTIONS = {
      "quit"       => :quit,
      "new-window" => :new_window,
    }.freeze

    # Shortcuts for actions, as upstream's ACTION_ACCELS.
    ACTION_ACCELS = {
      "win.apply"            => "<Ctrl>Return",
      "win.copy"             => "<Ctrl><Shift>c",
      "win.open-preferences" => "<Ctrl>comma",
      "win.load-file"        => "<Ctrl>o",
      "win.save-as"          => "<Ctrl>s",
      "win.toggle-search"    => "<Alt>s",
      "win.jump-to-args"     => "<Ctrl>e",
      "window.close"         => "<Ctrl>w",
      "app.quit"             => "<Ctrl>q",
      "app.new-window"       => "<Ctrl>n",
    }.freeze

    attr_reader :settings, :tools

    def initialize(app_id: APP_ID, flags: :handles_open, settings: nil, tools: nil)
      @app_id = app_id
      @flags = flags
      @settings = settings || Settings.new
      @tools = tools || ToolsController.new
      @windows = []
    end

    def build
      app.tap do |application|
        application.signal_connect("startup") { on_startup }
        application.signal_connect("activate") { new_window }
        application.signal_connect("open") { |_, files, _n, _hint| open(files) }
        application.signal_connect("shutdown") { on_shutdown }
      end
    end

    def run(argv = []) = app.run(argv)

    # Upstream's new_window action.
    def new_window
      Window.new(app, settings: @settings, tools: @tools, accels: ACTION_ACCELS)
            .tap do |window|
              @windows << window
              window.build
              window.present
            end
    end

    def quit = app.quit

    # Upstream's open: one window per file, each showing that file's contents.
    def open(files)
      Array(files).each do |file|
        new_window.load_from(file)
      end
    end

    # Adwaita::Application is broken in the Ruby bindings; the application
    # object comes from Gtk and only the windows are Adwaita.
    def app = @app ||= Gtk::Application.new(@app_id, @flags)

    # The provider carrying the CSS Recoloring generates for the current style
    # scheme. Upstream installs the same provider at the same priority.
    def style_scheme_provider = @style_scheme_provider ||= Gtk::CssProvider.new

    private

      def on_startup
        Style.install
        install_scheme_provider
        install_icons
        register_actions
        register_accels
        @settings.subscribe("style-scheme") { |id| apply_style_scheme(id) }
        @tools.load
      end

      def register_actions
        ACTIONS.each do |name, method_name|
          app.add_action(
            Gio::SimpleAction.new(name).tap do |action|
              action.signal_connect("activate") { send(method_name) }
            end,
          )
        end
      end

      def register_accels
        ACTION_ACCELS.each do |action, accelerator|
          app.set_accels_for_action(action, [accelerator])
        end
      end

      def install_scheme_provider
        Gdk::Display.default.then do |display|
          if display
            Gtk::StyleContext.add_provider_for_display(
              display,
              style_scheme_provider,
              Gtk::StyleProvider::PRIORITY_USER,
            )
          end
        end
      end

      # The status icons the tools use and the application's own icon are
      # shipped with the port; upstream loads them from its gresource.
      def install_icons
        Gdk::Display.default.then do |display|
          if display
            Gtk::IconTheme.get_for_display(display).add_search_path(ICON_DIR)
          end
        end
      end

      # Upstream's style_scheme setter: the interface follows the scheme's
      # darkness and the generated CSS redefines the Adwaita colours.
      def apply_style_scheme(id)
        find_scheme(id).then do |scheme|
          if scheme
            Adwaita::StyleManager.default.color_scheme = color_scheme(scheme)
            style_scheme_provider.load_from_string(Recoloring.generate_css(scheme))
          end
        end
      end

      # The scheme the settings name, falling back to the default and then to
      # whatever is installed, so a settings file naming a scheme this
      # install does not have still starts.
      def find_scheme(id)
        GtkSource::StyleSchemeManager.default.then do |manager|
          manager.get_scheme(id.to_s) ||
            manager.get_scheme("Adwaita-dark") ||
            manager.get_scheme(manager.scheme_ids.first)
        end
      end

      def color_scheme(scheme)
        if Recoloring.scheme_dark?(scheme)
          :force_dark
        else
          :force_light
        end
      end

      # Upstream saves the geometry of the active window, or of the window a
      # dialog belongs to, as the application shuts down.
      def on_shutdown
        @windows.each(&:save_window_size)
      end
  end
end
