import 'package:flutter_test/flutter_test.dart';
import 'package:venera_next/foundation/webdav_connection.dart';

WebDavConnectionMigration inspect(Map<String, Object?> settings) =>
    WebDavConnectionMigration.inspect((key) => settings[key]);

void main() {
  test('consistent legacy credentials migrate without a confirmation flag', () {
    final settings = <String, Object?>{
      'webdav': ['https://dav.example', 'user', 'pass'],
      'backupWebdav': ['https://dav.example', 'user', 'pass'],
      'webdavComicLibrary': ['https://dav.example', 'user', 'pass'],
    };

    final result = inspect(settings);

    expect(result.changed, isTrue);
    expect(result.pendingConfirmation, isFalse);
    expect(result.connection.url, 'https://dav.example');
    expect(result.connection.user, 'user');
    expect(result.connection.password, 'pass');
    expect(result.changes[webDavConnectionKey], {
      'url': 'https://dav.example',
      'user': 'user',
      'pass': 'pass',
    });
    expect(
      result.changes,
      isNot(contains(webDavConnectionPendingConfirmationKey)),
    );
    // Legacy keys are retained for one release cycle.
    expect(settings['webdav'], ['https://dav.example', 'user', 'pass']);
    expect(settings['backupWebdav'], ['https://dav.example', 'user', 'pass']);
    expect(settings['webdavComicLibrary'], [
      'https://dav.example',
      'user',
      'pass',
    ]);
  });

  test(
    'inconsistent legacy credentials prefer data sync and ask to confirm',
    () {
      final settings = <String, Object?>{
        'webdav': ['https://sync.example', 'sync-user', 'sync-pass'],
        'backupWebdav': ['https://backup.example', '', ''],
        'webdavComicLibrary': ['https://library.example', '', ''],
      };

      final result = inspect(settings);

      expect(result.pendingConfirmation, isTrue);
      expect(result.connection.url, 'https://sync.example');
      expect(result.changes[webDavConnectionPendingConfirmationKey], isTrue);
      expect(
        (result.changes[webDavConnectionKey]! as Map)['url'],
        'https://sync.example',
      );
    },
  );

  test('a fresh user gets an explicit empty shared record', () {
    final settings = <String, Object?>{
      'webdav': <String>[],
      'backupWebdav': <String>[],
      'webdavComicLibrary': <String>[],
    };

    final result = inspect(settings);

    expect(result.changed, isTrue);
    expect(result.pendingConfirmation, isFalse);
    expect(result.connection.isEmpty, isTrue);
    expect(result.changes[webDavConnectionKey], {
      'url': '',
      'user': '',
      'pass': '',
    });
    expect(
      result.changes,
      isNot(contains(webDavConnectionPendingConfirmationKey)),
    );
  });

  test('backup-only legacy credentials still migrate', () {
    final settings = <String, Object?>{
      'webdav': <String>[],
      'backupWebdav': ['https://backup.example', 'backup-user', 'secret'],
    };

    final result = inspect(settings);

    expect(result.connection.url, 'https://backup.example');
    expect(result.pendingConfirmation, isFalse);
  });

  test('an existing shared record is never replaced by legacy values', () {
    final settings = <String, Object?>{
      'webdav.connection': {
        'url': 'https://shared.example',
        'user': 'shared',
        'pass': 'shared-pass',
      },
      'webdav': ['https://old.example', '', ''],
      'backupWebdav': ['https://other.example', '', ''],
    };

    final result = inspect(settings);

    expect(result.changed, isFalse);
    expect(result.connection.url, 'https://shared.example');
    expect(result.pendingConfirmation, isFalse);
  });
}
