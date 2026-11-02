# frozen_string_literal: true

require "gtk4"

# Accelerator turns an accelerator string into a GTK shortcut.
#
# Upstream writes its widget-local shortcuts in Blueprint, where a
# ShortcutController holds `Shortcut { trigger: "<Ctrl>f"; action:
# "action(search.show)" }` and the compiler parses both halves. Blueprint's
# parser is not available here and Gtk::ShortcutTrigger.parse_string is not
# bound, so the same two strings are turned into a Gtk::Shortcut through
# Gtk.accelerator_parse and Gtk::NamedAction.
module Accelerator
  class << self
    def shortcut(accelerator, action_name)
      Gtk::Shortcut.new(trigger(accelerator), Gtk::NamedAction.new(action_name))
    end

    def trigger(accelerator)
      Gtk.accelerator_parse(accelerator).then do |ok, keyval, modifiers|
        if ok
          Gtk::KeyvalTrigger.new(keyval, modifiers)
        end
      end
    end

    # Builds a controller holding one shortcut per accelerator => action pair.
    def controller(scope, shortcuts)
      Gtk::ShortcutController.new.tap do |controller|
        controller.scope = scope
        shortcuts.each do |accelerator, action_name|
          controller.add_shortcut(shortcut(accelerator, action_name))
        end
      end
    end
  end
end
