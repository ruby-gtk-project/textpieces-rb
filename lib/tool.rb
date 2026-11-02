# frozen_string_literal: true

require "gtk4"
require "open3"
require "digest"
require "securerandom"
require_relative "utils"
require_relative "translation"

# ScriptResult is what running a tool script produced: the transformed text,
# the error message, or one of each.
#
# Ported from the ScriptResult struct in upstream's src/tools/Tool.vala. Both
# members are nullable there and nil here: output is nil when the script
# exited non-zero, error is nil when it wrote nothing to stderr.
ScriptResult = Data.define(:output, :error)

# Tool is one text transformation: metadata plus the script that performs it.
#
# Ported from upstream's src/tools/Tool.vala. A GLib::Object subclass rather
# than a plain Ruby one because the tool list models are Gio::ListStores, and
# those hold GObjects.
class Tool < GLib::Object
  type_register

  DEFAULT_ICON = "applications-utilities-symbolic"

  # The directory holding the pre-installed scripts — upstream's
  # Config.SCRIPTDIR, which the build system points at the installed
  # pkgdatadir. Here it is the scripts/ directory shipped beside lib/.
  SYSTEM_TOOLS_DIR = File.expand_path("../scripts", __dir__)

  class << self
    def in_flatpak? = @in_flatpak ||= File.exist?("/.flatpak-info")

    # Custom tools live in ~/.local/share/textpieces/scripts even under
    # Flatpak, because a sandboxed app cannot write into another app's
    # directory even through the portals.
    def custom_tools_dir
      @custom_tools_dir ||= File.join(
        Dir.home,
        ".local",
        "share",
        "textpieces",
        "scripts",
      ).tap { |dir| Utils.ensure_directory_exists(dir) }
    end

    # Generates "name-salt", where the salt is the first eight characters of
    # the SHA256 of a random number, so two tools with the same name still get
    # separate scripts.
    def generate_filename(name)
      Digest::SHA256.hexdigest(SecureRandom.random_number(1 << 32).to_s)
                    .slice(0, 8)
                    .then do |salt|
        "#{name.to_s.downcase.tr(' ', '_').tr('?', 'x')}-#{salt}"
      end
    end
  end

  attr_reader :name, :description, :arguments, :icon, :script, :is_system

  def initialize(name: "", description: "", arguments: [], icon: DEFAULT_ICON,
                 script: "", is_system: false)
    super()
    @name = name
    @description = description
    @arguments = arguments
    @icon = icon
    @script = script
    @is_system = is_system
    @observers = []
  end

  def system? = @is_system

  # Upstream's tools notify their window when any property changes, so the
  # tool button and the argument entries follow an edit made in the
  # preferences window. #on_change is that notify signal.
  def on_change(&block)
    @observers << block
    block
  end

  def off_change(block)
    @observers.delete(block)
  end

  def name=(value)
    @name = value.to_s
    changed
  end

  def description=(value)
    @description = value.to_s
    changed
  end

  def arguments=(value)
    @arguments = Array(value).map(&:to_s)
    changed
  end

  def script=(value)
    @script = value.to_s
    changed
  end

  def icon=(value)
    @icon = value.to_s
    changed
  end

  def translated_name = Translation.tools(@name)
  def translated_description = Translation.tools(@description)
  def translated_arguments = @arguments.map { |argument| Translation.tools(argument) }

  def script_dir
    if system?
      SYSTEM_TOOLS_DIR
    else
      self.class.custom_tools_dir
    end
  end

  def script_path = File.join(script_dir, @script)

  # Runs the script with the given arguments, feeding it the text on stdin.
  #
  # The output is nil when the script failed, so a failed run leaves the
  # editor's text alone; the error is nil when stderr was empty, so a
  # successful run shows no toast. Custom scripts under Flatpak are run on the
  # host through flatpak-spawn, as upstream does.
  def apply(input, args)
    Open3.capture3(*command_line(args), stdin_data: input)
         .then do |stdout, stderr, status|
      ScriptResult.new(
        output: status.success? ? stdout : nil,
        error:  stderr.to_s.empty? ? nil : Utils.escape_markup(stderr),
      )
    end
  rescue SystemCallError, IOError => e
    ScriptResult.new(output: nil, error: Utils.escape_markup(e.message))
  end

  # Opens the script in whatever editor the desktop uses for it. Upstream asks
  # the OpenURI portal for a writable handler; Gtk::FileLauncher is the same
  # request made through GTK, which goes to the portal inside a sandbox and to
  # the desktop's handler outside one. Pre-installed tools are not editable.
  def open(window)
    unless system?
      Gtk::FileLauncher.new(Gio::File.new_for_path(script_path))
                       .tap { |launcher| launcher.always_ask = true }
                       .launch(window, nil) { |launcher, result| finish_launch(launcher, result) }
    end
  end

  def to_h
    {
      "name"        => @name,
      "description" => @description,
      "script"      => @script,
      "args"        => @arguments,
    }
  end

  private

    def changed
      @observers.each { |block| block.call(self) }
    end

    def command_line(args)
      [].tap do |cmdline|
        if !system? && self.class.in_flatpak?
          cmdline.push("flatpak-spawn", "--host")
        end
        cmdline << script_path
        cmdline.concat(Array(args).map(&:to_s))
      end
    end

    def finish_launch(launcher, result)
      launcher.launch_finish(result)
    rescue GLib::Error
      nil
    end
end
