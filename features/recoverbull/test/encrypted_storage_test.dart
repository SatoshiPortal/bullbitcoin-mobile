import 'dart:convert';
import 'dart:io';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/backup_metadata_repository_impl.dart';
import 'package:bull_recoverbull/src/data/database/recoverbull_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final key = DatabaseKey.fromHex('42' * 32);
  late Directory directory;
  late String path;
  late RecoverBullStorage owner;
  final server = Uri.parse('http://first.onion');
  final context = VaultContext(
    fingerprint: Fingerprint('73c5da0a'),
    network: BitcoinNetwork.mainnet,
  );
  final vault = EncryptedVault(
    id: '11' * 32,
    salt: '22' * 16,
    ciphertext: List.filled(64, 0),
    createdAt: DateTime.utc(2026),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('recoverbull-encrypted-');
    path = '${directory.path}/recoverbull.sqlite';
    owner = RecoverBullStorage(path, key: key);
  });

  tearDown(() async {
    await owner.dispose();
    await directory.delete(recursive: true);
  });

  test('metadata is encrypted and survives reopening', () async {
    final repository = BackupMetadataRepositoryImpl(await owner.open());
    _ok(await repository.markVerified(context, vault));
    _ok(await repository.changeServer(server));
    _ok(await repository.acceptServer(server));
    await owner.dispose();

    final bytes = await File(path).readAsBytes();
    expect(
      bytes.take(16).toList(),
      isNot(utf8.encode('SQLite format 3\u0000')),
    );
    final raw = sqlite3.open(path);
    try {
      expect(
        () => raw.select('SELECT * FROM recoverbull_state'),
        throwsA(anything),
      );
    } finally {
      raw.close();
    }

    owner = RecoverBullStorage(path, key: key);
    final reopened = BackupMetadataRepositoryImpl(await owner.open());
    expect(_ok(await reopened.status(context)).isVerified, isTrue);
    final settings = _ok(await reopened.settings());
    expect(settings.server, server);
    expect(settings.permissionGranted, isTrue);
  });
}

T _ok<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw StateError(failure.runtimeType.toString()),
};
