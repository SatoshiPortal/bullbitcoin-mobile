import 'dart:convert';
import 'dart:io';

import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/domain/entities/monitored_backup.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const email = 'alice.backup@example.com';

  test('the Google account e-mail never reaches the database file', () async {
    final directory = await Directory.systemTemp.createTemp('recoverbull');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/recoverbull.sqlite');
    final database = RecoverBullDatabase.forTesting(NativeDatabase(file));
    await database.ensureState();
    final store = RecoverBullAttemptMonitoringStore(database);
    final digest = List<int>.filled(32, 7);

    await store.reconcileDriveBackups(email, [
      DriveBackupObservation(
        fileId: 'file-1',
        digest: digest,
        createdAt: DateTime.utc(2026, 9, 1),
        modifiedAt: null,
      ),
    ]);
    await store.saveDriveCache(
      account: email,
      driveFileId: 'file-2',
      backupDigest: digest,
      createdAt: DateTime.utc(2026, 9, 2),
    );
    await store.registerBackup(
      [1, 2, 3],
      origin: MonitoredBackupOrigin.drive,
      driveAccount: email,
      driveFileId: 'file-3',
    );

    // Reconciliation still matches the same account through its hash.
    expect(await store.driveBackups(email), hasLength(2));
    expect(await store.driveCache(email), hasLength(2));
    await database.close();

    final needle = utf8.encode(email);
    for (final path in [file.path, '${file.path}-wal']) {
      final stored = File(path);
      if (!stored.existsSync()) continue;
      expect(
        _contains(stored.readAsBytesSync(), needle),
        isFalse,
        reason: '$path holds the plaintext e-mail',
      );
    }
  });
}

bool _contains(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
