# frozen_string_literal: true

require "adwaita"
require "fileutils"
require_relative "tool"
require_relative "tool_settings"
require_relative "translation"
require_relative "utils"

# NewToolPage is the preferences subpage that creates a custom tool.
#
# Ported from upstream's src/widgets/preferences/pages/NewToolPage.vala and
# resources/ui/NewToolPage.blp: the same form as the edit page, without script
# editing, and a Create button that only appears once the tool has a name.
#
# Creating copies the script template shipped with the port to a generated
# filename, makes it executable, adds the tool to the index, saves it and
# opens the new script in the user's editor — upstream's sequence exactly.
class NewToolPage
  SCRIPT_MODE = 0o750
  TEMPLATE = "template"

  def initialize(preferences:, tools:)
    @preferences = preferences
    @tools = tools
    @tool = Tool.new(name: "", description: "", arguments: [], script: "", is_system: false)
  end

  def build
    root.tap do |box|
      box.append(header_bar)
      box.append(tool_settings.build)

      header_bar.tap do |bar|
        bar.pack_start(back_button)
        bar.title_widget = title_label
        bar.pack_end(create_revealer)

        create_revealer.child = create_button

        back_button.signal_connect("clicked") { go_back }
        create_button.signal_connect("clicked") { create }
      end

      tool_settings.on_validity_changed { |valid| create_revealer.reveal_child = valid }
    end
  end

  def widget = root

  # Memoized widget methods

  def root = @root ||= Gtk::Box.new(:vertical, 0)

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.show_start_title_buttons = false
      bar.show_end_title_buttons = false
    end
  end

  def back_button
    @back_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = "go-previous-symbolic"
    end
  end

  def title_label
    @title_label ||= Gtk::Label.new(Translation.t("New Tool")).tap do |label|
      label.add_css_class("heading")
    end
  end

  def create_revealer
    @create_revealer ||= Gtk::Revealer.new.tap do |revealer|
      revealer.transition_type = :crossfade
    end
  end

  def create_button
    @create_button ||= Gtk::Button.new.tap do |button|
      button.label = Translation.t("_Create")
      button.use_underline = true
      button.add_css_class("suggested-action")
    end
  end

  def tool_settings
    @tool_settings ||= ToolSettings.new(@tool, window: @preferences.window)
  end

  private

    def go_back
      @preferences.close_subpage
    end

    def create
      write_script
      @tools.add_tool(@tool)
      commit
      @tool.open(@preferences.window)
      go_back
    end

    def write_script
      Utils.ensure_directory_exists(Tool.custom_tools_dir)
      Tool.generate_filename(@tool.name).then do |filename|
        File.join(Tool.custom_tools_dir, filename).then do |path|
          FileUtils.cp(File.join(Tool::SYSTEM_TOOLS_DIR, TEMPLATE), path)
          FileUtils.chmod(SCRIPT_MODE, path)
          @tool.script = filename
        end
      end
    end

    def commit
      @tools.commit
    rescue SystemCallError => e
      warn "Can't commit tools: #{e.message}"
      @preferences.add_toast(Adwaita::Toast.new(format(Translation.t("Error occured: %s"), e.message)))
    end
end
