import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/data/nostr_key_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File file;
  late SqliteDatabase database;
  late NostrKeyRepositoryImpl repository;
  final time = DateTime.utc(2026, 9, 18);
  NostrKeyRecord key({
    String? publicKey,
    String purpose = 'Personal',
    DateTime? updatedAt,
  }) => NostrKeyRecord(
    parentFingerprint: 'aabbccdd',
    identity: 1,
    publicKey: publicKey ?? 'a' * 64,
    purpose: purpose,
    description: 'Notes',
    createdAt: time,
    updatedAt: updatedAt ?? time,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'bull-nostr-record-test-',
    );
    file = File('${directory.path}/keys.sqlite');
    database = SqliteDatabase(NativeDatabase(file));
    repository = NostrKeyRepositoryImpl(database);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  Future<List<NostrKeyRecord>> all() async =>
      (await repository.getAll()
              as Ok<List<NostrKeyRecord>, KeychainManifestFailure>)
          .value;

  test('only public inventory and user annotations survive restart', () async {
    expect(await repository.insert(key()), isA<Ok>());
    await database.close();
    database = SqliteDatabase(NativeDatabase(file));
    repository = NostrKeyRepositoryImpl(database);
    final stored = (await all()).single;
    expect(stored.publicKey, 'a' * 64);
    expect(stored.derivationPath, "128002'/1'/1'");
    expect(stored.purpose, 'Personal');
    expect(stored.description, 'Notes');
    expect(stored.createdAt, time);
    final columns =
        (await database
                .customSelect('PRAGMA table_info(keychain_nostr_keys)')
                .get())
            .map((row) => row.read<String>('name'));
    expect(columns, isNot(anyElement(contains('secret'))));
  });

  test(
    'an origin/index collision cannot replace a different public key',
    () async {
      expect(await repository.insert(key()), isA<Ok>());
      expect(await repository.insert(key(publicKey: 'b' * 64)), isA<Err>());
      expect((await all()).single.publicKey, 'a' * 64);
    },
  );

  test(
    'recovery preserves existing annotations and only adds missing records',
    () async {
      expect(await repository.insert(key(purpose: 'Local edit')), isA<Ok>());
      expect(
        await repository.restore(key(purpose: 'Recovered older label')),
        isA<Ok>(),
      );
      expect((await all()).single.purpose, 'Local edit');
    },
  );
}
