import 'dart:convert';
import 'preferences.dart';
import 'reader_preferences.dart';
import 'reader_settings.dart';
import 'comic_layout.dart';

const readerPresetModeKeys = {
  'readerMode',
  'autoReaderMode',
  'pagedReaderMode',
  'longStripReaderMode',
};

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

/// Pure view of persisted bindings. Legacy references are checked against raw
/// layers exactly once when next admitted; explicit bindings never value-match.
class ReaderPresetValues {
  ReaderPresetValues(this.data);
  final Map data;
  Map record(String container, String key) {
    final records = data[container];
    final value = records is Map ? records[key] : null;
    return value is Map ? value : const {};
  }

  Map? preset(String id) {
    final items = data['readerModePresets'];
    if (items is! List) return null;
    for (final item in items) {
      if (item is Map &&
          item['id'] == id &&
          item['name'] is String &&
          item['values'] is Map) {
        return {
          for (final p in readerPresetPreferences)
            if (item['values'].containsKey(p.key))
              p.key: p.normalize(item['values'][p.key]),
        };
      }
    }
    return null;
  }

  bool inherits(String id) {
    final items = data['readerModePresets'];
    if (items is List) {
      for (final item in items) {
        if (item is Map &&
            item['id'] == id &&
            item['name'] is String &&
            item['values'] is Map) {
          return item['modeBehavior'] == 'inherit';
        }
      }
    }
    return false;
  }

  String? selected(String target) {
    final selections = data['readerPresetSelections'];
    final id = selections is Map ? selections[target] : null;
    if (id is! String || id.isEmpty) return null;
    final values = preset(id);
    if (values == null || values.isEmpty && !inherits(id)) return null;
    List identity;
    try {
      identity = jsonDecode(target) as List;
    } catch (_) {
      return null;
    }
    if (!(identity.length == 1 && identity[0] == 'global' ||
        identity.length == 2 &&
            identity[0] == 'device' &&
            identity[1] is String ||
        identity.length == 3 &&
            identity[0] == 'comic' &&
            identity[1] is String &&
            identity[2] is String)) {
      return null;
    }
    final bindings = data['readerPresetBindings'];
    if (bindings is Map && bindings[target] == id) return id;
    // Inherit is an explicit post-migration behavior, never an old snapshot
    // reference whose value mismatch could silently reapply fixed settings.
    if (inherits(id)) return id;
    final global = data;
    final device = identity.first == 'device'
        ? record('deviceSpecificSettings', identity[1].toString())
        : record('deviceSpecificSettings', data['deviceId'].toString());
    final comic = identity.first == 'comic' && identity.length == 3
        ? record('comicSpecificSettings', '${identity[2]}@${identity[1]}')
        : const {};
    final detection = identity.first == 'comic'
        ? record('comicLayoutDetections', '${identity[2]}@${identity[1]}')
        : const {};
    final effective = ReaderSettings.resolve(
      global: global,
      device: identity.first == 'global' ? null : device,
      comic: identity.first == 'comic' ? comic : null,
      layout: detection['version'] == ComicLayoutDetection.version
          ? ComicLayout.fromKey(detection['layout'])
          : ComicLayout.unknown,
    );
    Object? raw(String key) => identity.first == 'global'
        ? global[key]
        : (comic['enabled'] == true ? comic[key] : null) ??
              (device['enabled'] == true ? device[key] : null) ??
              global[key];
    for (final p in readerPresetPreferences) {
      final actual = switch (p.key) {
        'readerMode' => effective.readerMode,
        'longPressAction' => effective.longPressAction,
        _ => p.normalize(raw(p.key)),
      };
      if (values.containsKey(p.key) && values[p.key] != actual) return null;
    }
    return id;
  }

  Map layer(String target, Map raw, {bool comic = false}) {
    final id = selected(target);
    final values = id == null ? null : preset(id);
    final inherit = id != null && inherits(id);
    final global = target == jsonEncode(['global']);
    return {
      ...raw,
      if (values != null)
        for (final entry in values.entries)
          if (!inherit || !readerPresetModeKeys.contains(entry.key))
            entry.key: entry.value,
      if (inherit && !global)
        for (final key in readerPresetModeKeys) key: null,
      if (comic && inherit) 'readerModeOverride': 'default',
      if (comic && !inherit && values?.containsKey('readerMode') == true)
        'readerModeOverride': values!['readerMode'],
    };
  }

  void migrate() {
    final raw = data['readerPresetSelections'];
    if (raw is! Map) return;
    final selections = <String, String>{};
    for (final key in raw.keys.whereType<String>()) {
      final id = selected(key);
      if (id != null) selections[key] = id;
    }
    data['readerPresetSelections'] = selections;
    data['readerPresetBindings'] = Map<String, String>.of(selections);
  }
}
