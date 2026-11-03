import 'package:venera_next/foundation/app.dart';
import 'package:venera_next/foundation/appdata.dart';

/// Only explicit search-page choices belong here; defaults and options do not.
class SearchSelection {
  static final _pending = <String, int>{};
  static final _beforePending = <String, Object?>{};
  static bool isSaving(String path) => (_pending[path] ?? 0) > 0;
  // Appdata publishes drafts before IO. A page reopened during that interval
  // must read the durable choice and wait for the writer's final notification.
  static SearchSelection? read(String path) => decode(
    isSaving(path) ? _beforePending[path] : appdata.settings[recoveryKey],
  );
  const SearchSelection({
    required this.aggregated,
    required this.sourceKey,
    required this.profileId,
  });
  final bool aggregated;
  final String? sourceKey;
  final String? profileId;

  static SearchSelection? decode(Object? raw) {
    if (raw is! Map ||
        raw['version'] is! int ||
        raw['version'] != 1 ||
        !const ['single', 'aggregated'].contains(raw['mode']) ||
        !raw.containsKey('sourceKey') ||
        !raw.containsKey('profileId') ||
        (raw['sourceKey'] != null && raw['sourceKey'] is! String) ||
        (raw['profileId'] != null && raw['profileId'] is! String)) {
      return null;
    }
    return SearchSelection(
      aggregated: raw['mode'] == 'aggregated',
      sourceKey: raw['sourceKey'] as String?,
      profileId: raw['profileId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'mode': aggregated ? 'aggregated' : 'single',
    'sourceKey': sourceKey,
    'profileId': profileId,
  };

  static const recoveryKey = 'searchSelection';
  Future<void> save(String path) async {
    if (!isSaving(path)) _beforePending[path] = appdata.settings[recoveryKey];
    _pending[path] = (_pending[path] ?? 0) + 1;
    try {
      await appdata.updateSettings((draft) {
        // Check inside admitted work as well as in the page before submission.
        if (App.dataPath != path) {
          throw StateError('Settings directory changed');
        }
        draft[recoveryKey] = toJson();
      }, recoveryKey: recoveryKey);
    } finally {
      final remaining = _pending[path]! - 1;
      if (remaining == 0) {
        _pending.remove(path);
        _beforePending.remove(path);
      } else {
        _pending[path] = remaining;
      }
      if (App.dataPath == path) appdata.settings.notifyListeners();
    }
  }
}
