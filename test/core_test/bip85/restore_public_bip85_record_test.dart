import 'package:bb_mobile/core/bip85/data/bip85_datasource.dart';
import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase db;
  late Bip85Datasource owner;
  late Bip85Repository repository;
  Bip85DerivationEntity record({
    String path = "39'/0'/12'/8'",
    String fingerprint = 'aabbccdd',
    int index = 8,
    String alias = 'Recovered',
  }) => Bip85DerivationEntity(
    path: path,
    xprvFingerprint: fingerprint,
    alias: alias,
    status: Bip85Status.active,
    application: Bip85Application.bip39,
    index: index,
  );
  setUp(() {
    db = SqliteDatabase(NativeDatabase.memory());
    owner = Bip85Datasource(sqlite: db);
    repository = Bip85Repository(datasource: owner);
  });
  tearDown(() => db.close());
  test('restore needs no secret and affects normal allocation', () async {
    expect(await repository.restorePublicRecord(record()), isA<Ok>());
    final stored = (await owner.fetchAll()).single;
    expect(stored.path, "39'/0'/12'/8'");
    expect(stored.alias, 'Recovered');
    final next = await repository.fetchNextIndexForApplication(
      Bip85Application.bip39,
    );
    expect((next as Ok).value, 9);
  });
  test('existing local alias and revocation survive replay', () async {
    expect(await repository.restorePublicRecord(record()), isA<Ok>());
    await owner.alias("39'/0'/12'/8'", 'Edited locally');
    await owner.revoke("39'/0'/12'/8'");
    expect(await repository.restorePublicRecord(record()), isA<Ok>());
    final restored = (await owner.fetchAll()).single;
    expect(restored.alias, 'Edited locally');
    expect(restored.status.name, 'revoked');
  });
  test(
    'a path owned by another seed is a conflict and never overwritten',
    () async {
      expect(await repository.restorePublicRecord(record()), isA<Ok>());
      expect(
        await repository.restorePublicRecord(record(fingerprint: '11223344')),
        isA<Err>(),
      );
      expect((await owner.fetchAll()).single.xprvFingerprint, 'aabbccdd');
    },
  );
  test(
    'reserved, noncanonical, mismatched and out-of-range paths cannot be restored',
    () async {
      for (final value in [
        record(path: "39'/0'/12'/100'", index: 100),
        record(path: "39'/0'/12'/2147483648'", index: 2147483648),
        record(path: "39'/0'/12'/08'"),
        record(path: "39'/999999999999999999999999999999999'/12'/8'"),
        record(path: "m/39'/0'/12'/8'"),
        record(path: "39'/0'/12'/9'"),
        record(path: "128169'/32'/8'"),
        record(fingerprint: 'not-a-fingerprint'),
      ]) {
        expect(await repository.restorePublicRecord(value), isA<Err>());
      }
      expect(await owner.fetchAll(), isEmpty);
    },
  );
}
