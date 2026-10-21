import 'package:venera_next/foundation/preferences.dart';
import 'reader_preference_settings.dart';
import 'reader_preferences.dart';

enum ReaderPreferenceScope { active, global, device, comic }

/// Typed edits over the existing persistence format. Resolving an active scope
/// happens on each operation so toggling a scope cannot leave a stale binding.
class ReaderPreferenceStore {
  ReaderPreferenceStore({
    required this.settings,
    this.scope = ReaderPreferenceScope.active,
    this.comicId,
    this.sourceKey,
  }) {
    if ((comicId == null) != (sourceKey == null) ||
        (scope == ReaderPreferenceScope.comic && comicId == null)) {
      throw ArgumentError(
        'Comic settings require both comic ID and source key',
      );
    }
  }

  final ReaderPreferenceSettings settings;
  final ReaderPreferenceScope scope;
  final String? comicId;
  final String? sourceKey;

  T read<T>(Preference<T> preference) =>
      preference.normalize(readRaw(preference.key));

  /// Legacy nullable fields share scope resolution with typed preferences.
  Object? readRaw(String key) {
    if (scope == ReaderPreferenceScope.global) {
      return settings[key];
    } else if (scope == ReaderPreferenceScope.comic ||
        (scope == ReaderPreferenceScope.active && comicId != null)) {
      return settings.getReaderSetting(comicId!, sourceKey!, key);
    } else {
      return settings.getDeviceReaderSetting(key);
    }
  }

  void write<T>(Preference<T> preference, T value) {
    final normalized = preference.normalize(value);
    writeRaw(preference.key, normalized);
    if (preference.key == ReaderPreferences.showChapterComments.key &&
        normalized == false) {
      write(ReaderPreferences.showChapterCommentsAtEnd, false);
    }
  }

  /// Manual mode follows the full form's dedicated comic override. Unlike
  /// other comic edits, it must not activate unrelated saved comic settings.
  void writeComicModeOverride(String value) {
    if (scope != ReaderPreferenceScope.comic) {
      throw StateError('A manual comic mode requires comic scope');
    }
    settings.setReaderSetting(
      comicId!,
      sourceKey!,
      'readerModeOverride',
      ReaderPreferences.readerMode.normalize(value),
    );
  }

  /// The remaining heterogeneous fields keep their JSON representation and
  /// use the same write target. Typed writes additionally enforce their rules.
  void writeRaw(String key, Object? value) {
    // Preserve the existing slider JSON representation for whole numbers.
    final stored = value is num && value.toInt() == value
        ? value.toInt()
        : value;
    switch (scope) {
      case ReaderPreferenceScope.global:
        settings[key] = stored;
      case ReaderPreferenceScope.device:
        settings.setDeviceReaderSetting(key, stored);
        // An explicit device-scope edit activates the device layer so the
        // value is not shadowed by the global fallback.
        if (key != 'enabled') {
          settings.setDeviceReaderSetting('enabled', true);
        }
      case ReaderPreferenceScope.comic:
        settings.setReaderSetting(comicId!, sourceKey!, key, stored);
        // An explicit comic-scope edit activates this comic's overrides.
        if (key != 'enabled') {
          settings.setReaderSetting(comicId!, sourceKey!, 'enabled', true);
        }
      case ReaderPreferenceScope.active:
        settings.setActiveReaderSetting(comicId, sourceKey, key, stored);
    }
  }
}
