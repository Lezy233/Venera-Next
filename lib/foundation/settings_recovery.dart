import 'dart:convert';
import 'translations.dart';

/// A local, opt-in transaction failure. Both failures remain available to
/// diagnostics; an absent recovery error means durable compensation succeeded.
class SettingsRecoveryFailure implements Exception {
  const SettingsRecoveryFailure(
    this.initialError,
    this.initialStack, [
    this.recoveryError,
    this.recoveryStack,
  ]);
  final Object initialError;
  final StackTrace initialStack;
  final Object? recoveryError;
  final StackTrace? recoveryStack;
  bool get incomplete => recoveryError != null;
  @override
  String toString() => incomplete
      ? '${"Save failed; recovery incomplete".tl}: $initialError; $recoveryError'
      : '${"Save failed; previous settings restored".tl}: $initialError';
}

final _absent = Object();

/// Three-way rollback at field granularity. A later writer owns any value that
/// differs from the published assignment. Missing fields retain their absence.
Map<String, dynamic> restoreOwnedSettings(
  Map before,
  Map applied,
  Map current,
) {
  bool equal(Object? a, Object? b) =>
      identical(a, _absent) || identical(b, _absent)
      ? identical(a, b)
      : jsonEncode(a) == jsonEncode(b);
  Object? restore(Object? old, Object? written, Object? now) {
    if (equal(old, written)) return now;
    if (equal(written, now)) return old;
    if ((old is Map || identical(old, _absent)) &&
        (written is Map || identical(written, _absent)) &&
        now is Map) {
      final result = Map<String, dynamic>.from(now);
      final oldMap = old is Map ? old : const {};
      final writtenMap = written is Map ? written : const {};
      for (final key in {...oldMap.keys, ...writtenMap.keys}) {
        final value = restore(
          oldMap.containsKey(key) ? oldMap[key] : _absent,
          writtenMap.containsKey(key) ? writtenMap[key] : _absent,
          now.containsKey(key) ? now[key] : _absent,
        );
        if (identical(value, _absent)) {
          result.remove(key);
        } else {
          result[key as String] = value;
        }
      }
      return identical(old, _absent) && result.isEmpty ? _absent : result;
    }
    return now;
  }

  return Map<String, dynamic>.from(restore(before, applied, current) as Map);
}
