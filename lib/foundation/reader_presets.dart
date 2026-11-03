import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'app.dart';
import 'translations.dart';

import 'appdata.dart';
import 'comic_layout.dart';
import 'reader_preference_store.dart';
import 'reader_preferences.dart';
import 'reader_preset_values.dart';
export 'reader_preset_values.dart' show readerPresetPreferences;
import 'reader_settings.dart';

class ReaderPreset {
  ReaderPreset(
    this.id,
    this.name,
    Map<String, Object> values, {
    String modeBehavior = 'fixed',
  }) : modeBehavior = modeBehavior == 'inherit' ? 'inherit' : 'fixed',
       values = Map.unmodifiable(values);
  final String id, name;
  final String modeBehavior;
  final Map<String, Object> values;
  bool get inheritsMode => modeBehavior == 'inherit';
  bool get isValid => values.isNotEmpty || inheritsMode;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'values': values,
    'modeBehavior': modeBehavior,
  };
}

/// UI translates the message key; storage validation remains UI-independent.
class ReaderPresetNameError implements Exception {
  const ReaderPresetNameError(this.messageKey);
  final String messageKey;
}

/// Presets carry values only. The caller supplies a scope and optional comic
/// identity; each operation captures that context before joining the writer.
class ReaderPresetStore {
  const ReaderPresetStore({
    this.scope = ReaderPreferenceScope.global,
    this.comicId,
    this.sourceKey,
  }) : _path = null,
       _deviceId = null,
       _admittedDeviceId = null;
  final ReaderPreferenceScope scope;
  final String? comicId, sourceKey;

  const ReaderPresetStore._bound(
    this.scope,
    this.comicId,
    this.sourceKey,
    this._path,
    this._deviceId,
    this._admittedDeviceId,
  );
  final String? _path, _deviceId;
  final Object? _admittedDeviceId;

  /// Freeze ownership before waiting for the serialized writer.
  ReaderPresetStore capture() {
    if (_path != null) return this;
    var target = scope;
    if (target == ReaderPreferenceScope.active) {
      target =
          appdata.settings.isComicSpecificSettingsEnabled(comicId, sourceKey)
          ? ReaderPreferenceScope.comic
          : appdata.settings.isDeviceSpecificSettingsEnabled()
          ? ReaderPreferenceScope.device
          : ReaderPreferenceScope.global;
    }
    return ReaderPresetStore._bound(
      target,
      comicId,
      sourceKey,
      App.dataPath,
      (appdata.settings['deviceId'] is String &&
              (appdata.settings['deviceId'] as String).isNotEmpty)
          ? appdata.settings['deviceId'] as String
          : target == ReaderPreferenceScope.device
          ? const Uuid().v4()
          : null,
      appdata.settings['deviceId'],
    );
  }

  String get selectionKey => switch (scope) {
    ReaderPreferenceScope.global => jsonEncode(['global']),
    ReaderPreferenceScope.device => jsonEncode([
      'device',
      _deviceId ?? appdata.settings['deviceId'],
    ]),
    ReaderPreferenceScope.comic => jsonEncode(['comic', sourceKey, comicId]),
    ReaderPreferenceScope.active => capture().selectionKey,
  };

  String get recoveryKey => scope == ReaderPreferenceScope.device
      ? jsonEncode([
          'device',
          _path == null ? appdata.settings['deviceId'] : _admittedDeviceId,
        ])
      : selectionKey;

  bool get isCurrent =>
      _path == null ||
      (_path == App.dataPath &&
          (_deviceId == appdata.settings['deviceId'] ||
              _admittedDeviceId == appdata.settings['deviceId']));

  void _checkPath() {
    if (_path != null && _path != App.dataPath) {
      throw StateError('The reading settings data directory has changed'.tl);
    }
  }

  SettingsRecoveryFailure? get recovery {
    final path = _path ?? App.dataPath;
    final id = appdata.settings.readerPresetId(selectionKey);
    return appdata.settingsRecovery(path, recoveryKey) ??
        (id == null
            ? null
            : appdata.settingsRecovery(path, jsonEncode(['preset', id])));
  }

  Future<void> retryRecovery() {
    final owner = capture();
    if (!owner.isCurrent) {
      return Future.error(StateError('Reading settings target changed'.tl));
    }
    final id = appdata.settings.readerPresetId(owner.selectionKey);
    final key =
        appdata.settingsRecovery(owner._path!, owner.recoveryKey) != null
        ? owner.recoveryKey
        : jsonEncode(['preset', id]);
    return appdata.retrySettingsRecovery(owner._path, key);
  }

  List<ReaderPreset> get list => _list(appdata.settings);

  String? get selectedId {
    if (scope == ReaderPreferenceScope.active) return capture().selectedId;
    if (recovery != null) return null;
    return appdata.settings.readerPresetId(selectionKey);
  }

  void _select(Settings settings, String? id) {
    final raw = settings['readerPresetSelections'];
    final selections = <String, dynamic>{
      if (raw is Map)
        for (final entry in raw.entries)
          if (entry.key is String) entry.key as String: entry.value,
    };
    if (id == null) {
      selections.remove(selectionKey);
    } else {
      selections[selectionKey] = id;
    }
    settings['readerPresetSelections'] = selections;
    final bindings = settings['readerPresetBindings'];
    settings['readerPresetBindings'] = {
      if (bindings is Map) ...bindings,
      selectionKey: id,
    };
  }

  Future<void> clearSelection() {
    final target = capture();
    return appdata.updateSettings((settings) {
      target._checkPath();
      final id = settings.readerPresetId(target.selectionKey);
      settings.readerTransaction(target.selectionKey, [?id]);
      target._preserve(settings);
      target._select(settings, null);
    }, recoveryKey: target.recoveryKey);
  }

  Future<void> reset() {
    final target = capture();
    return appdata.updateSettings((settings) {
      target._checkPath();
      final id = settings.readerPresetId(target.selectionKey);
      settings.readerTransaction(target.selectionKey, [?id]);
      target._withDevice(settings, () {
        switch (target.scope) {
          case ReaderPreferenceScope.global:
            settings.resetGlobalReaderSettings();
          case ReaderPreferenceScope.device:
            settings.resetDeviceReaderSettings();
            settings.setEnabledDeviceSpecificSettings(true);
          case ReaderPreferenceScope.comic:
            settings.resetComicReaderSettings(
              '${target.comicId}@${target.sourceKey}',
            );
            settings.setEnabledComicSpecificSettings(
              target.comicId!,
              target.sourceKey!,
              true,
            );
          case ReaderPreferenceScope.active:
            throw StateError('Unresolved scope');
        }
      });
      target._select(settings, null);
    }, recoveryKey: target.recoveryKey);
  }

  T _withDevice<T>(Settings settings, T Function() action) {
    final previous = settings['deviceId'];
    if (scope == ReaderPreferenceScope.device && _deviceId != null) {
      settings['deviceId'] = _deviceId;
    }
    try {
      return action();
    } finally {
      if (scope == ReaderPreferenceScope.device &&
          _deviceId != null &&
          previous is String &&
          previous.isNotEmpty) {
        settings['deviceId'] = previous;
      }
    }
  }

  List<ReaderPreset> _list(Settings settings) {
    final raw = settings['readerModePresets'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map &&
            item['id'] is String &&
            item['name'] is String &&
            item['values'] is Map)
          ReaderPreset(
            item['id'] as String,
            item['name'] as String,
            {
              for (final preference in readerPresetPreferences)
                if ((item['values'] as Map).containsKey(preference.key))
                  preference.key: preference.normalize(
                    item['values'][preference.key],
                  ),
            },
            modeBehavior: item['modeBehavior'] == 'inherit'
                ? 'inherit'
                : 'fixed',
          ),
    ];
  }

  void _write(Settings settings, List<ReaderPreset> items) {
    settings['readerModePresets'] = items.map((item) => item.toJson()).toList();
  }

  String _name(String input, List<ReaderPreset> items, [String? except]) {
    final name = input.trim();
    if (name.isEmpty) throw const ReaderPresetNameError('Enter a preset name');
    if (name.runes.length > 30) {
      throw const ReaderPresetNameError(
        'Preset names must be at most 30 characters',
      );
    }
    if (items.any(
      (item) =>
          item.id != except && item.name.toLowerCase() == name.toLowerCase(),
    )) {
      throw const ReaderPresetNameError('This preset name is already used');
    }
    return name;
  }

  Map<String, Object> _snapshot(Settings settings) {
    final store = ReaderPreferenceStore(
      settings: settings,
      scope: scope,
      comicId: comicId,
      sourceKey: sourceKey,
    );
    final values = <String, Object>{
      for (final preference in readerPresetPreferences)
        preference.key: store.read(preference),
    };
    // Comic reads already resolve the independent mode override and layout.
    // Global/device snapshots resolve auto mode within their own effective layer.
    values['readerMode'] =
        scope == ReaderPreferenceScope.comic ||
            (scope == ReaderPreferenceScope.active && comicId != null)
        ? settings.readerSettings(comicId!, sourceKey!).readerMode
        : ReaderSettings.resolve(
            global: values,
            layout: ComicLayout.unknown,
          ).readerMode;
    values['autoReaderMode'] = false;
    return values;
  }

  Future<ReaderPreset> createFromCurrent(String name) {
    final id = const Uuid().v4();
    return appdata.updateSettings((settings) {
      final items = _list(settings);
      final preset = ReaderPreset(id, _name(name, items), _snapshot(settings));
      _write(settings, [...items, preset]);
      return preset;
    });
  }

  Future<void> rename(String id, String name) =>
      appdata.updateSettings((settings) {
        final items = _list(settings);
        final normalized = _name(name, items, id);
        _write(settings, [
          for (final item in items)
            item.id == id
                ? ReaderPreset(
                    id,
                    normalized,
                    item.values,
                    modeBehavior: item.modeBehavior,
                  )
                : item,
        ]);
      });

  Future<void> updateFromCurrent(String id) {
    final owner = capture();
    return appdata.updateSettings((settings) {
      owner._checkPath();
      settings.readerTransaction(owner.selectionKey, [id]);
      final snapshot = owner._snapshot(settings);
      _write(settings, [
        for (final item in _list(settings))
          item.id == id ? ReaderPreset(id, item.name, snapshot) : item,
      ]);
    }, recoveryKey: owner.recoveryKey);
  }

  void _preserve(Settings settings, {bool switching = false}) {
    final id = settings.readerPresetId(selectionKey);
    final preset = _list(settings).where((p) => p.id == id).firstOrNull;
    if (preset == null) return;
    final deviceBefore = settings['deviceId'];
    try {
      settings.materializeReaderValues(
        () => _withDevice(settings, () {
          for (final entry in preset.values.entries) {
            if (readerPresetModeKeys.contains(entry.key) &&
                (preset.inheritsMode ||
                    switching && scope == ReaderPreferenceScope.global)) {
              continue;
            }
            final value =
                entry.value is num &&
                    (entry.value as num).toInt() == entry.value
                ? (entry.value as num).toInt()
                : entry.value;
            // Preserve the layer's enable switch while detaching its latest values.
            switch (scope) {
              case ReaderPreferenceScope.global:
                settings[entry.key] = value;
              case ReaderPreferenceScope.device:
                settings.setDeviceReaderSetting(entry.key, value);
              case ReaderPreferenceScope.comic:
                settings.setReaderSetting(
                  comicId!,
                  sourceKey!,
                  entry.key == 'readerMode' ? 'readerModeOverride' : entry.key,
                  value,
                );
              case ReaderPreferenceScope.active:
                throw StateError('Unresolved scope');
            }
          }
          if (preset.inheritsMode) {
            settings.preserveReaderModeInheritance(
              scope.name,
              comicId,
              sourceKey,
            );
          }
        }),
      );
    } finally {
      if (scope == ReaderPreferenceScope.device) {
        settings['deviceId'] = deviceBefore;
      }
    }
  }

  Future<void> delete(String id) {
    final owner = capture();
    return appdata.updateSettings((settings) {
      owner._checkPath();
      settings.readerTransaction(owner.selectionKey, [id]);
      final selections = settings['readerPresetSelections'];
      if (selections is Map) {
        for (final key in selections.keys.toList()) {
          if (selections[key] != id || key is! String) continue;
          List identity;
          try {
            identity = jsonDecode(key) as List;
          } catch (_) {
            continue;
          }
          final target = switch (identity.first) {
            'global' => const ReaderPresetStore(),
            'device' => ReaderPresetStore._bound(
              ReaderPreferenceScope.device,
              null,
              null,
              owner._path,
              identity[1] as String?,
              identity[1] as String?,
            ),
            'comic' => ReaderPresetStore(
              scope: ReaderPreferenceScope.comic,
              sourceKey: identity[1] as String?,
              comicId: identity[2] as String?,
            ),
            _ => null,
          };
          if (target != null) {
            settings.readerTransaction(key, [id]);
            target._preserve(settings);
            target._select(settings, null);
          }
        }
      }
      _write(settings, _list(settings).where((item) => item.id != id).toList());
    }, recoveryKey: owner.recoveryKey);
  }

  Future<List<String>> apply(String id, ReaderPreferenceScope target) {
    final owner = target == scope
        ? capture()
        : ReaderPresetStore(
            scope: target,
            comicId: comicId,
            sourceKey: sourceKey,
          ).capture();
    return owner._apply(id);
  }

  Future<List<String>> _apply(String id) => appdata.updateSettings((settings) {
    _checkPath();
    final preset = _list(settings).where((item) => item.id == id).firstOrNull;
    if (preset == null || !preset.isValid) return <String>[];
    final previous = settings.readerPresetId(selectionKey);
    settings.readerTransaction(selectionKey, [id, ?previous]);
    _preserve(settings, switching: true);
    settings.materializeReaderValues(
      () => _withDevice(settings, () {
        final store = ReaderPreferenceStore(
          settings: settings,
          scope: scope,
          comicId: comicId,
          sourceKey: sourceKey,
        );
        for (final entry in preset.values.entries) {
          // Global raw mode fields are the independent base for inherit.
          // Bound fixed values already resolve through the shared library.
          if (readerPresetModeKeys.contains(entry.key) &&
              (preset.inheritsMode || scope == ReaderPreferenceScope.global)) {
            continue;
          }
          if (entry.key == ReaderPreferences.readerMode.key &&
              scope == ReaderPreferenceScope.comic) {
            store.writeComicModeOverride(entry.value as String);
          } else {
            store.writeRaw(entry.key, entry.value);
          }
        }
        if (preset.inheritsMode) {
          settings.preserveReaderModeInheritance(
            scope.name,
            comicId,
            sourceKey,
          );
        }
      }),
    );
    // A first device edit may create the existing settings device identity.
    final keyOwner = _deviceId == null && scope == ReaderPreferenceScope.device
        ? ReaderPresetStore._bound(
            scope,
            comicId,
            sourceKey,
            _path,
            settings['deviceId'] as String?,
            _admittedDeviceId,
          )
        : this;
    keyOwner._select(settings, id);
    return {
      ...preset.values.keys,
      if (preset.inheritsMode) 'readerMode',
    }.toList();
  }, recoveryKey: recoveryKey);
}
