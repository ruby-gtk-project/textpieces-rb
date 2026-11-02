# frozen_string_literal: true

require "adwaita"
require_relative "translation"

# ShortcutsWindow lists the keyboard shortcuts.
#
# Ported from resources/ui/ShortcutsWindow.blp, group for group and item for
# item, including the items the template names by action rather than by
# accelerator: those are resolved through the application's accelerator table,
# which is what GTK does for the upstream window.
#
# Upstream's widget is a Gtk.ShortcutsWindow, which the Ruby bindings cannot
# instantiate ("GtkWindow is not subtype of GtkShortcutsWindow"), so this is
# an Adw.ShortcutsDialog — its replacement in current Adwaita — presented by
# the same win.show-help-overlay action the menu item uses.
class ShortcutsWindow
  # title => accelerator, or title => action name for the items the template
  # leaves to the application's accelerators.
  GROUPS = {
    "General"            => [
      ["New window", "app.new-window"],
      ["Keyboard shortcuts", "win.show-help-overlay"],
      ["Preferences", "win.open-preferences"],
      ["Close window", "window.close"],
      ["Quit", "app.quit"],
    ],
    "Tools"              => [
      ["Apply", "win.apply"],
      ["Select tool", "win.toggle-search"],
      ["Just to the tool options", "win.jump-to-args"],
    ],
    "Undo and Redo"      => [
      ["Undo", "<ctrl>z"],
      ["Redo", "<ctrl><shift>z"],
    ],
    "Files"              => [
      ["Load from file", "win.load-file"],
      ["Save to file", "win.save-as"],
    ],
    "Search and Replace" => [
      ["Search", "<ctrl>f"],
      ["Replace", "<ctrl>h"],
      ["Move to previous match", "<Shift>Return"],
      ["Move to next match", "Return"],
    ],
  }.freeze

  def initialize(accels = {})
    @accels = accels
  end

  def build
    dialog.tap do |window|
      GROUPS.each do |title, items|
        window.add(section(title, items))
      end
    end
  end

  def present(parent)
    build.present(parent)
  end

  def dialog
    @dialog ||= Adwaita::ShortcutsDialog.new.tap do |window|
      window.title = Translation.t("Keyboard Shortcuts")
    end
  end

  private

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |group|
        group.title = Translation.t(title)
        items.each do |label, accelerator|
          accelerator_for(accelerator).then do |accel|
            if accel
              group.add(item(label, accel))
            end
          end
        end
      end
    end

    # An entry is either an accelerator already or the name of an action whose
    # accelerator the application knows. An action with no accelerator has
    # nothing to show, so it is left out, as it is in upstream's window.
    def accelerator_for(entry)
      if entry.include?(".")
        @accels[entry]
      else
        entry
      end
    end

    # Positional, not keyword, arguments — even though the error a no-argument
    # new raises advertises the signatures as "title: utf8, accelerator: utf8".
    def item(label, accelerator)
      Adwaita::ShortcutsItem.new(Translation.t(label), accelerator)
    end
end
