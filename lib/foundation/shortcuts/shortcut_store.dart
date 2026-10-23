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

  Future<ShortcutAction?> _edit(
    String id,
    List<SingleActivator> Function(List<SingleActivator>) change,
  ) => appdata.updateSettings((draft) {
    final values = AppShortcutRegistry.overrides(draft['shortcutOverrides']);
    final current = AppShortcutRegistry.resolve(
      values,
      macOS: App.isMacOS,
    )[id]!;
    final proposed = change(current);
    final encoded = <String>{};
    for (final binding in proposed) {
      final conflict = AppShortcutRegistry.conflict(
        id,
        binding,
        values,
        macOS: App.isMacOS,
      );
      if (conflict != null) return conflict;
      encoded.add(ShortcutCodec.encode(binding));
    }
    values[id] = encoded.toList();
    draft['shortcutOverrides'] = values;
    return null;
  }, persistIfUnchanged: false);

  /// Replace all bindings (or explicitly clear them).
  Future<ShortcutAction?> assign(String id, SingleActivator? binding) =>
      _edit(id, (_) => binding == null ? [] : [binding]);

  Future<ShortcutAction?> add(String id, SingleActivator binding) =>
      _edit(id, (bindings) => [...bindings, binding]);

  /// Identify the edited binding by encoding, not an index that can go stale.
  Future<ShortcutAction?> replace(
    String id,
    String old,
    SingleActivator binding,
  ) => _edit(
    id,
    (bindings) => [
      for (final current in bindings)
        ShortcutCodec.encode(current) == old ? binding : current,
    ],
  );

  Future<ShortcutAction?> remove(String id, String code) => _edit(
    id,
    (bindings) => [
      for (final binding in bindings)
        if (ShortcutCodec.encode(binding) != code) binding,
    ],
  );

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
