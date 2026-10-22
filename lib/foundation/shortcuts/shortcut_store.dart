import 'package:flutter/widgets.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'shortcut_registry.dart';

/// All edits are checked again inside appdata's serialized draft transaction.
class ShortcutStore {
  const ShortcutStore();
  Map<String, List<SingleActivator>> get effective =>
      AppShortcutRegistry.resolve(
        appdata.settings['shortcutOverrides'],
        macOS: App.isMacOS,
      );

  Future<ShortcutAction?> assign(String id, SingleActivator? binding) =>
      appdata.updateSettings((draft) {
        final values = AppShortcutRegistry.overrides(
          draft['shortcutOverrides'],
        );
        if (binding != null) {
          final conflict = AppShortcutRegistry.conflict(
            id,
            binding,
            values,
            macOS: App.isMacOS,
          );
          if (conflict != null) return conflict;
        }
        values[id] = binding == null ? '' : ShortcutCodec.encode(binding);
        draft['shortcutOverrides'] = values;
        return null;
      }, persistIfUnchanged: false);

  Future<void> reset([String? id]) => appdata.updateSettings((draft) {
    final values = AppShortcutRegistry.overrides(draft['shortcutOverrides']);
    if (id == null) {
      values.clear();
    } else {
      values.remove(id);
    }
    draft['shortcutOverrides'] = values;
  });
}
