import 'dart:async';

import 'package:flutter/material.dart';
import 'package:venera_next/components/appbar.dart';
import 'package:venera_next/components/settings_save_state.dart';
import 'package:venera_next/design_system/tokens.dart';
import 'package:venera_next/foundation/appdata.dart';
import 'package:venera_next/foundation/context.dart';
import 'package:venera_next/foundation/reader_presets.dart';
import 'package:venera_next/foundation/translations.dart';

import 'setting_components.dart';

/// Both entry points use the same library and scoped apply path. The selection
/// is a local reminder of the last application, never a second preference.
class ReaderPresetSelector extends StatefulWidget {
  const ReaderPresetSelector({
    super.key,
    required this.store,
    required this.onChanged,
    this.showManagement = false,
    this.isCurrent,
  });
  final ReaderPresetStore store;
  final ValueChanged<String> onChanged;
  final bool showManagement;
  final bool Function()? isCurrent;

  @override
  State<ReaderPresetSelector> createState() => _ReaderPresetSelectorState();
}

class _ReaderPresetSelectorState
    extends SettingsSaveState<ReaderPresetSelector> {
  String? _appliedId;

  @override
  void initState() {
    super.initState();
    appdata.settings.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _applied(String id, List<String> keys) {
    if (!mounted || widget.isCurrent?.call() == false) return;
    setState(() => _appliedId = id);
    for (final key in keys) {
      if (!mounted || widget.isCurrent?.call() == false) return;
      widget.onChanged(key);
    }
  }

  Future<void> _apply(String id) async {
    if (!acceptsSettingsChanges || widget.isCurrent?.call() == false) return;
    if (id.isEmpty) {
      setState(() => _appliedId = null);
      return;
    }
    final store = widget.store;
    var keys = <String>[];
    await saveSetting(
      ('reader-preset', store.scope, store.comicId, store.sourceKey),
      () async {
        keys = await store.apply(id, store.scope);
      },
      onSaved: () => _applied(id, keys),
      isCurrent: () =>
          mounted &&
          widget.isCurrent?.call() != false &&
          widget.store.scope == store.scope &&
          widget.store.comicId == store.comicId &&
          widget.store.sourceKey == store.sourceKey,
    );
  }

  Future<void> _manage() async {
    if (!acceptsSettingsChanges) return;
    await waitForSettingsSave();
    if (!mounted) return;
    final store = widget.store;
    final work = context
        .getInheritedWidgetOfExactType<SettingsSaveScope>()
        ?.work;
    await context.to(() {
      final page = ReaderPresetManagement(store: store, onApplied: _applied);
      return work == null ? page : SettingsSaveScope(work: work, child: page);
    });
  }

  @override
  Widget build(BuildContext context) {
    final presets = widget.store.list;
    final selected = presets.any((item) => item.id == _appliedId)
        ? _appliedId!
        : '';
    return withSettingsSaveFeedback(
      protectSettings(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: DropdownButtonFormField<String>(
                key: ValueKey('reader-preset-selection-$selected'),
                initialValue: selected,
                decoration: InputDecoration(
                  labelText:
                      (widget.showManagement ? 'Current preset' : 'Preset').tl,
                ),
                isExpanded: true,
                items: [
                  DropdownMenuItem(value: '', child: Text('None'.tl)),
                  for (final preset in presets)
                    DropdownMenuItem(
                      value: preset.id,
                      child: Text(preset.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: savingSettings
                    ? null
                    : (id) {
                        if (id != null) unawaited(_apply(id));
                      },
              ),
            ),
            if (widget.showManagement)
              CallbackSetting(
                title: 'Manage presets…'.tl,
                callback: _manage,
                actionTitle: 'Manage'.tl,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    appdata.settings.removeListener(_refresh);
    super.dispose();
  }
}

class ReaderPresetManagement extends StatefulWidget {
  const ReaderPresetManagement({
    super.key,
    required this.store,
    required this.onApplied,
  });
  final ReaderPresetStore store;
  final void Function(String, List<String>) onApplied;
  @override
  State<ReaderPresetManagement> createState() => _ReaderPresetManagementState();
}

class _ReaderPresetManagementState extends State<ReaderPresetManagement> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    appdata.settings.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appdata.settings.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _edit(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _name([ReaderPreset? preset]) => showDialog<void>(
    context: context,
    builder: (_) => _PresetNameDialog(
      name: preset?.name,
      save: (name) => _edit(() async {
        if (preset == null) {
          await widget.store.createFromCurrent(name);
        } else {
          await widget.store.rename(preset.id, name);
        }
      }),
    ),
  );

  Future<void> _action(ReaderPreset preset, String action) async {
    if (_busy) return;
    if (action == 'rename') {
      await _name(preset);
      return;
    }
    if (action != 'apply') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            (action == 'delete' ? 'Delete preset' : 'Update preset').tl,
          ),
          content: Text(
            (action == 'delete'
                    ? 'Delete this preset? Applied settings will be kept.'
                    : 'Replace this preset with the current reading settings?')
                .tl,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'.tl),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Confirm'.tl),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      await _edit(() async {
        switch (action) {
          case 'apply':
            final keys = await widget.store.apply(
              preset.id,
              widget.store.scope,
            );
            widget.onApplied(preset.id, keys);
          case 'update':
            await widget.store.updateFromCurrent(preset.id);
          case 'delete':
            await widget.store.delete(preset.id);
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = widget.store.list;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: Appbar(title: Text('Reading mode presets'.tl)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: _busy ? null : _name,
                  child: Text('New preset'.tl),
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (presets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    'No presets yet. Create one from your current reading settings.'
                        .tl,
                  ),
                ),
              for (final preset in presets)
                ListTile(
                  title: Text(preset.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _action(preset, 'apply'),
                        child: Text('Apply'.tl),
                      ),
                      PopupMenuButton<String>(
                        enabled: !_busy,
                        onSelected: (action) => _action(preset, action),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename'.tl),
                          ),
                          PopupMenuItem(
                            value: 'update',
                            child: Text('Update to current settings'.tl),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'.tl),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetNameDialog extends StatefulWidget {
  const _PresetNameDialog({required this.name, required this.save});
  final String? name;
  final Future<void> Function(String) save;
  @override
  State<_PresetNameDialog> createState() => _PresetNameDialogState();
}

class _PresetNameDialogState extends State<_PresetNameDialog> {
  late final _name = TextEditingController(text: widget.name);
  bool _busy = false;
  String? _error;
  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save(_name.text);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ReaderPresetNameError
              ? error.messageKey.tl
              : error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text((widget.name == null ? 'New preset' : 'Rename preset').tl),
      content: TextField(
        controller: _name,
        autofocus: true,
        enabled: !_busy,
        decoration: InputDecoration(
          labelText: 'Preset name'.tl,
          errorText: _error,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text('Cancel'.tl),
        ),
        TextButton(onPressed: _busy ? null : _save, child: Text('Save'.tl)),
      ],
    ),
  );
}
