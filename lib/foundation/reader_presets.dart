import 'package:uuid/uuid.dart';

import 'appdata.dart';
import 'comic_layout.dart';
import 'preferences.dart';
import 'reader_preference_store.dart';
import 'reader_preferences.dart';
import 'reader_settings.dart';

/// Fixed snapshot boundary. New preferences do not enter old presets implicitly.
const readerPresetPreferences = <Preference<Object>>[
  ReaderPreferences.readerMode,
  ReaderPreferences.autoReaderMode,
  ReaderPreferences.pagedReaderMode,
  ReaderPreferences.longStripReaderMode,
  ReaderPreferences.readerScreenPicNumberForPortrait,
  ReaderPreferences.readerScreenPicNumberForLandscape,
  ReaderPreferences.showSingleImageOnFirstPage,
  ReaderPreferences.limitImageWidth,
  ReaderPreferences.readerSideMargin,
  ReaderPreferences.splitDualPage,
  ReaderPreferences.splitDualPageInvert,
  ReaderPreferences.enablePageAnimation,
  ReaderPreferences.enableTapToTurnPages,
  ReaderPreferences.reverseTapToTurnPages,
  ReaderPreferences.enableDoubleTapToZoom,
  ReaderPreferences.longPressAction,
  ReaderPreferences.longPressZoomPosition,
  ReaderPreferences.quickCollectImage,
  ReaderPreferences.enableTurnPageByVolumeKey,
];

class ReaderPreset {
  ReaderPreset(this.id, this.name, Map<String, Object> values)
    : values = Map.unmodifiable(values);
  final String id, name;
  final Map<String, Object> values;

  Map<String, Object> toJson() => {'id': id, 'name': name, 'values': values};
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
  });
  final ReaderPreferenceScope scope;
  final String? comicId, sourceKey;

  List<ReaderPreset> get list => _list(appdata.settings);

  List<ReaderPreset> _list(Settings settings) {
    final raw = settings['readerModePresets'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map &&
            item['id'] is String &&
            item['name'] is String &&
            item['values'] is Map)
          ReaderPreset(item['id'] as String, item['name'] as String, {
            for (final preference in readerPresetPreferences)
              if ((item['values'] as Map).containsKey(preference.key))
                preference.key: preference.normalize(
                  item['values'][preference.key],
                ),
          }),
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
            item.id == id ? ReaderPreset(id, normalized, item.values) : item,
        ]);
      });

  Future<void> updateFromCurrent(String id) => appdata.updateSettings((
    settings,
  ) {
    _write(settings, [
      for (final item in _list(settings))
        item.id == id ? ReaderPreset(id, item.name, _snapshot(settings)) : item,
    ]);
  });

  Future<void> delete(String id) => appdata.updateSettings((settings) {
    _write(settings, _list(settings).where((item) => item.id != id).toList());
  });

  Future<List<String>> apply(String id, ReaderPreferenceScope target) =>
      appdata.updateSettings((settings) {
        final preset = _list(
          settings,
        ).where((item) => item.id == id).firstOrNull;
        if (preset == null) return <String>[];
        final store = ReaderPreferenceStore(
          settings: settings,
          scope: target,
          comicId: comicId,
          sourceKey: sourceKey,
        );
        for (final entry in preset.values.entries) {
          if (entry.key == ReaderPreferences.readerMode.key &&
              target == ReaderPreferenceScope.comic) {
            store.writeComicModeOverride(entry.value as String);
          } else {
            store.writeRaw(entry.key, entry.value);
          }
        }
        return preset.values.keys.toList();
      });
}
