# frozen_string_literal: true

require "adwaita"
require_relative "argument_row"
require_relative "translation"

# ToolSettings is the form behind both custom-tool subpages: name,
# description, how many arguments the tool takes, a row per argument, and —
# for a tool that already exists — a row that opens its script.
#
# Ported from upstream's src/widgets/preferences/ToolSettings.vala and
# resources/ui/ToolSettings.blp. Upstream wraps each argument in an Argument
# object inside a ListStore and binds the entries to it bidirectionally; the
# tool's own arguments array is the single source of truth here, resized by
# the spin button and written through by the rows.
#
# The form reports whether what it holds is valid — a tool needs a name —
# which is what reveals the Create button on the new-tool page.
class ToolSettings
  MAX_ARGUMENTS = 100
  CLAMP_SIZE = 400

  def initialize(tool, window: nil, can_edit_script: false)
    @tool = tool
    @window = window
    @can_edit_script = can_edit_script
    @validity_observers = []
  end

  def valid? = !@tool.name.to_s.empty?

  def on_validity_changed(&block)
    @validity_observers << block
    block.call(valid?)
    block
  end

  def build
    scroller.tap do |window|
      window.child = viewport

      viewport.tap do |port|
        port.child = clamp
        clamp.child = content_box

        content_box.tap do |box|
          box.append(fields_list)
          box.append(edit_script_list)
          box.append(argument_list)

          fields_list.tap do |list|
            list.append(name_row)
            list.append(description_row)
            list.append(arguments_row)
          end

          edit_script_list.tap do |list|
            list.append(edit_script_row)
            list.visible = @can_edit_script
            edit_script_row.signal_connect("activated") { @tool.open(@window) }
          end
        end
      end

      name_entry.signal_connect("changed") { on_name_changed }
      description_entry.signal_connect("changed") { @tool.description = description_entry.text }
      arguments_number.signal_connect("value-changed") { resize_arguments }

      arguments_number.value = @tool.arguments.length
      rebuild_arguments
    end
  end

  def widget = scroller

  # Memoized widget methods

  def scroller = @scroller ||= Gtk::ScrolledWindow.new

  def viewport
    @viewport ||= Gtk::Viewport.new(nil, nil).tap do |port|
      port.vexpand = true
      port.scroll_to_focus = true
    end
  end

  def clamp
    @clamp ||= Adwaita::Clamp.new.tap do |widget|
      widget.maximum_size = CLAMP_SIZE
    end
  end

  def content_box
    @content_box ||= Gtk::Box.new(:vertical, 20).tap do |box|
      box.margin_top = 20
      box.margin_bottom = 20
    end
  end

  def fields_list = @fields_list ||= boxed_list
  def edit_script_list = @edit_script_list ||= boxed_list

  def argument_list
    @argument_list ||= boxed_list.tap do |list|
      list.visible = false
    end
  end

  def name_row
    @name_row ||= Adwaita::ActionRow.new.tap do |row|
      row.title = Translation.t("_Name")
      row.use_underline = true
      row.activatable_widget = name_entry
      row.add_suffix(name_entry)
    end
  end

  def description_row
    @description_row ||= Adwaita::ActionRow.new.tap do |row|
      row.title = Translation.t("_Description")
      row.use_underline = true
      row.activatable_widget = description_entry
      row.add_suffix(description_entry)
    end
  end

  def arguments_row
    @arguments_row ||= Adwaita::ActionRow.new.tap do |row|
      row.title = Translation.t("_Arguments")
      row.use_underline = true
      row.activatable_widget = arguments_number
      row.add_suffix(arguments_number)
    end
  end

  def edit_script_row
    @edit_script_row ||= Adwaita::ActionRow.new.tap do |row|
      row.title = Translation.t("Edit _Script")
      row.use_underline = true
      row.activatable = true
      row.add_suffix(
        Gtk::Image.new(icon_name: "document-edit-symbolic").tap do |image|
                image.valign = :center
              end,
      )
    end
  end

  # Enter in the name entry moves on to the description, as the upstream
  # template's activate handler does.
  def name_entry
    @name_entry ||= Gtk::Entry.new.tap do |entry|
      entry.valign = :center
      entry.text = @tool.name.to_s
      entry.signal_connect("activate") { description_entry.grab_focus }
    end
  end

  def description_entry
    @description_entry ||= Gtk::Entry.new.tap do |entry|
      entry.valign = :center
      entry.text = @tool.description.to_s
    end
  end

  def arguments_number
    @arguments_number ||= Gtk::SpinButton.new(arguments_adjustment, 1, 0).tap do |spin|
      spin.valign = :center
    end
  end

  def arguments_adjustment
    @arguments_adjustment ||= Gtk::Adjustment.new(
      0,
      0,
      MAX_ARGUMENTS,
      1,
      1,
      0,
    )
  end

  private

    def boxed_list
      Gtk::ListBox.new.tap do |list|
        list.add_css_class("boxed-list")
        list.selection_mode = :none
      end
    end

    # An empty name is refused: the tool keeps the name it had, the entry is
    # marked, and the form reports itself invalid.
    def on_name_changed
      if name_entry.text.to_s.empty?
        name_entry.add_css_class("error")
      else
        name_entry.remove_css_class("error")
        @tool.name = name_entry.text
      end
      notify_validity
    end

    def notify_validity
      @validity_observers.each { |block| block.call(valid?) }
    end

    # Growing the count appends empty arguments, shrinking it drops the last
    # ones, which is what upstream's two while loops do.
    def resize_arguments
      arguments_number.value.to_i.then do |count|
        @tool.arguments = resized(@tool.arguments, count)
        rebuild_arguments
      end
    end

    def resized(arguments, count)
      if count > arguments.length
        arguments + Array.new(count - arguments.length, "")
      else
        arguments.first(count)
      end
    end

    def rebuild_arguments
      clear_argument_rows
      @tool.arguments.each_with_index do |value, index|
        argument_list.append(ArgumentRow.build(index, value) { |text| write_argument(index, text) })
      end
      argument_list.visible = !@tool.arguments.empty?
    end

    def write_argument(index, text)
      @tool.arguments.dup.tap do |arguments|
        arguments[index] = text
        @tool.arguments = arguments
      end
    end

    def clear_argument_rows
      while argument_list.first_child
        argument_list.remove(argument_list.first_child)
      end
    end
end
