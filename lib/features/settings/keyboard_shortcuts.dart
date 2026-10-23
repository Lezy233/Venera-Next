import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/scroll.dart';
import 'package:venera_next/design_system/tokens.dart';
import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/shortcuts/shortcut_registry.dart';
import 'package:venera_next/foundation/shortcuts/shortcut_store.dart';
import 'package:venera_next/foundation/translations.dart';
import 'package:venera_next/foundation/widget_utils.dart';
import 'setting_components.dart';

class KeyboardShortcutsSettings extends StatefulWidget {
  const KeyboardShortcutsSettings({super.key});
  @override
  State<KeyboardShortcutsSettings> createState() =>
      _KeyboardShortcutsSettingsState();
}

class _KeyboardShortcutsSettingsState extends State<KeyboardShortcutsSettings> {
  final _store = const ShortcutStore();
  final _focus = FocusNode();
  String? _capturing;
  String? _replacing;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    appdata.settings.addListener(_refresh);
    _focus.addListener(_captureFocusChanged);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _captureFocusChanged() {
    if (!mounted || _focus.hasFocus || _capturing == null) return;
    setState(() {
      _capturing = null;
      _error = null;
    });
    if (identical(shortcutCaptureOwner.value, this)) {
      shortcutCaptureOwner.value = null;
    }
  }

  @override
  void dispose() {
    appdata.settings.removeListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(shortcutCaptureOwner.value, this)) {
        shortcutCaptureOwner.value = null;
      }
    });
    _focus.removeListener(_captureFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  void _capture(String id, [String? replacing]) {
    setState(() {
      _capturing = id;
      _replacing = replacing;
      _error = null;
    });
    shortcutCaptureOwner.value = this;
    _focus.requestFocus();
  }

  Future<void> _edit(Future<ShortcutAction?> Function() change) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final conflict = await change();
      if (!mounted) return;
      setState(() {
        if (conflict == null) {
          _capturing = null;
          _error = null;
          if (identical(shortcutCaptureOwner.value, this)) {
            shortcutCaptureOwner.value = null;
          }
        } else {
          _error = 'Already used by “@action”'.tlParams({
            'action': conflict.titleKey.tl,
          });
        }
      });
    } catch (error) {
      if (mounted) context.showMessage(message: '${'Error'.tl}: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    final id = _capturing;
    if (id == null) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        setState(() {
          _capturing = null;
          _error = null;
          if (identical(shortcutCaptureOwner.value, this)) {
            shortcutCaptureOwner.value = null;
          }
        });
      }
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        !_busy &&
        !ShortcutCodec.isModifier(event.logicalKey)) {
      final binding = ShortcutCodec.capture(event);
      final replacing = _replacing;
      unawaited(
        _edit(
          () => replacing == null
              ? _store.add(id, binding)
              : _store.replace(id, replacing, binding),
        ),
      );
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final effective = _store.effective;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _key,
      child: Material(
        child: SmoothCustomScrollView(
          slivers: [
            SliverAppbar(
              title: Text('Keyboard shortcuts'.tl),
              actions: [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _edit(() async {
                          await _store.reset();
                          return null;
                        }),
                  child: Text('Reset all shortcuts'.tl),
                ),
              ],
            ),
            for (final group in ShortcutContext.values) ...[
              SettingPartTitle(
                title:
                    (group == ShortcutContext.global
                            ? 'Global shortcuts'
                            : 'Reader shortcuts')
                        .tl,
                icon: group == ShortcutContext.global
                    ? Icons.keyboard
                    : Icons.menu_book,
              ),
              for (final action in shortcutActions.where(
                (a) => a.context == group,
              ))
                ListTile(
                  key: ValueKey(action.id),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  title: Text(action.titleKey.tl),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (effective[action.id]!.isEmpty) Text('No shortcut'.tl),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final binding in effective[action.id]!)
                            InputChip(
                              key: ValueKey(
                                'shortcut-binding-${action.id}-${ShortcutCodec.encode(binding)}',
                              ),
                              label: Text(
                                ShortcutCodec.format(
                                  binding,
                                  macOS: App.isMacOS,
                                ),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _capture(
                                      action.id,
                                      ShortcutCodec.encode(binding),
                                    ),
                              onDeleted: _busy
                                  ? null
                                  : () => _edit(
                                      () => _store.remove(
                                        action.id,
                                        ShortcutCodec.encode(binding),
                                      ),
                                    ),
                              deleteButtonTooltipMessage: 'Remove shortcut'.tl,
                            ),
                          TextButton.icon(
                            key: ValueKey('shortcut-add-${action.id}'),
                            onPressed: _busy ? null : () => _capture(action.id),
                            icon: const Icon(
                              Icons.add,
                              size: AppSizes.shellIconSize,
                            ),
                            label: Text('Add shortcut'.tl),
                          ),
                        ],
                      ),
                      if (_capturing == action.id)
                        Text('Press a new shortcut…'.tl),
                      if (_capturing == action.id && _error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Clear shortcut'.tl,
                        icon: const Icon(Icons.clear),
                        onPressed: _busy
                            ? null
                            : () => _edit(() => _store.assign(action.id, null)),
                      ),
                      IconButton(
                        tooltip: 'Reset shortcut'.tl,
                        icon: const Icon(Icons.restore),
                        onPressed: _busy
                            ? null
                            : () => _edit(() async {
                                await _store.reset(action.id);
                                return null;
                              }),
                      ),
                    ],
                  ),
                ).toSliver(),
            ],
          ],
        ),
      ),
    );
  }
}
