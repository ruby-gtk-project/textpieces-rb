# frozen_string_literal: true

require "gtk4"
require "json"
require_relative "tool"
require_relative "utils"

# ToolsController owns the tool list models and the custom tools index on disk.
#
# Ported from upstream's src/tools/ToolsController.vala: three list models —
# pre-installed tools, custom tools, and all of them together — loaded from two
# JSON indexes, plus the add/delete/commit cycle the preferences window drives.
# Deleting a tool queues its script for removal and only #commit erases it,
# exactly as upstream's removed_tools queue does.
#
# Each model is mirrored by a plain Ruby array, and that array — never the
# Gio::ListStore — is what every read goes through. The reason is memory
# safety: removing an item from a list store drops the reference keeping it
# alive, and a Ruby wrapper GTK hands back afterwards can point at freed
# memory, which segfaults rather than raising. The stores still drive the
# views; they are just not the source of truth.
class ToolsController
  SYSTEM_TOOLS_FILE = File.expand_path("../data/tools.json", __dir__)

  attr_reader :system_tools, :custom_tools, :all_tools, :system, :custom, :all

  def initialize(custom_tools_file: nil)
    @custom_tools_file = custom_tools_file || default_custom_tools_file
    @system_tools = Gio::ListStore.new(Tool)
    @custom_tools = Gio::ListStore.new(Tool)
    @all_tools = Gio::ListStore.new(Tool)
    @system = []
    @custom = []
    @all = []
    @removed_tools = []
    @delete_observers = []
  end

  def custom_tools_file = @custom_tools_file

  # Creates the custom tools index if it is missing, then loads both indexes.
  def load
    unless File.file?(@custom_tools_file)
      save_custom_tools
    end

    update_tools
  end

  def update_tools
    @system = load_tools_from_file(SYSTEM_TOOLS_FILE)
    @custom = load_tools_from_file(@custom_tools_file)
    replace(@system_tools, @system)
    replace(@custom_tools, @custom)
    update_all_tools
  end

  def update_all_tools
    @all = @system + @custom
    replace(@all_tools, @all)
  end

  # Upstream's `add_tool` signal, whose default handler appends to the custom
  # tools model.
  def add_tool(tool)
    @custom = @custom + [tool]
    replace(@custom_tools, @custom)
    tool
  end

  # Upstream's `delete_tool` signal: the tool leaves the model at once, its
  # script is deleted by the next #commit, and everything connected to the
  # signal — the main window, which unselects a deleted tool — is told.
  def delete_tool(tool)
    @custom = @custom - [tool]
    replace(@custom_tools, @custom)
    @removed_tools << tool
    @delete_observers.each { |block| block.call(tool) }
    tool
  end

  def on_delete_tool(&block)
    @delete_observers << block
    block
  end

  # Writes the index, refreshes the combined model and erases the scripts of
  # the tools deleted since the last commit.
  def commit
    save_custom_tools
    update_all_tools

    until @removed_tools.empty?
      @removed_tools.shift.then do |tool|
        File.delete(tool.script_path)
      rescue SystemCallError
        nil
      end
    end
  end

  def find_by_script(script)
    @all.find { |tool| tool.script == script }
  end

  # Gio::ListStore has no "this item changed" signal, so a row that must
  # redraw after an edit is announced by re-emitting items-changed for it.
  # Upstream's CustomToolPage does the same when its subpage closes.
  def notify_changed(tool)
    @custom.index(tool).then do |position|
      if position
        @custom_tools.items_changed(position, 1, 1)
      end
    end
  end

  private

    # Gio::ListStore#splice round-trips the objects intact, which a
    # remove_all-then-append does not.
    def replace(store, tools)
      store.splice(0, store.n_items, tools)
    end

    def default_custom_tools_file
      ENV.fetch("XDG_CONFIG_HOME", File.join(Dir.home, ".config"))
         .then { |dir| File.join(dir, "textpieces", "tools.json") }
    end

    # Reads one tools index. A missing file, unreadable JSON, a root that is
    # not an object or a tool without a script are all reported and skipped,
    # as upstream reports and skips them.
    def load_tools_from_file(path)
      [].tap do |tools|
        if File.file?(path)
          parse_index(path).then do |root|
            if root.is_a?(Hash)
              append_tools(tools, root)
            else
              warn "Can't load tools: #{path} doesn't contain valid JSON object"
            end
          end
        else
          warn "Can't load tools from non-existing file \"#{path}\""
        end
      end
    end

    def parse_index(path)
      JSON.parse(File.read(path))
    rescue JSON::ParserError => e
      warn "Can't load tools from \"#{path}\": #{e.message}"
      nil
    end

    def append_tools(tools, root)
      root["tools"].then do |list|
        if list.is_a?(Array)
          list.each { |entry| append_tool(tools, entry, root["is_system"] == true) }
        else
          warn "Can't load tools: file doesn't contain list of tools"
        end
      end
    end

    def append_tool(tools, entry, is_system)
      if !entry.is_a?(Hash)
        warn "Error while loading tools: tool is not JSON object"
      elsif !entry.key?("script")
        warn "Error while loading tools: tool has no script"
      else
        tools << build_tool(entry, is_system)
      end
    end

    def build_tool(entry, is_system)
      Tool.new(
        name:        entry.fetch("name", ""),
        description: entry.fetch("description", ""),
        icon:        entry.fetch("icon", Tool::DEFAULT_ICON),
        script:      entry["script"],
        is_system:   is_system,
        arguments:   arguments_of(entry),
      )
    end

    def arguments_of(entry)
      Array(entry["args"]).map do |argument|
        if argument.is_a?(String)
          argument
        else
          warn "Arguments of tools must be string"
          ""
        end
      end
    end

    def save_custom_tools
      Utils.ensure_directory_exists(File.dirname(@custom_tools_file))
      File.write(@custom_tools_file, "#{JSON.pretty_generate(index)}\n")
    end

    def index = { "tools" => @custom.map(&:to_h) }
end
