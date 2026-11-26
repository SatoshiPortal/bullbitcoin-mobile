import 'dart:io';

import 'package:bull_recoverbull/migration.dart';
import 'package:bull_recoverbull/storage.dart';
import 'package:bull_recoverbull/testing.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/testing.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory directory;
  late RecoverBullCutover mainnet;
  late RecoverBullCutover regtest;
  late LegacySource legacy;
  late StorageCutover cutover;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('rb-retirement-');
    File file(String name) => File('${directory.path}/$name.sqlite');
    FakeSecureStoragePlatform().install();
    mainnet = recoverBullCutoverForTesting(
      file: file('recoverbull'),
      standalone: file('standalone'),
    );
    regtest = recoverBullCutoverForTesting(
      file: file('recoverbull_regtest'),
      standalone: file('standalone_regtest'),
      regtest: true,
    );
    final store = LegacySourceStore(
      source: LegacySource(file('legacy'), SqliteDatabase.currentSchemaVersion),
      create: SqliteDatabase.new,
    );
    legacy = store.source;
    final participants = [
      SecretsImport(file: file('secrets')),
      mainnet.participant,
      regtest.participant,
    ];
    cutover = StorageCutover(
      directory: Directory('${directory.path}/coordination'),
      legacy: store,
      expectedOwners: participants.map((owner) => owner.ownerId).toSet(),
      participants: participants,
    );
  });

  tearDown(() async {
    await LifecycleAdmission.retryQuarantined();
    await directory.delete(recursive: true);
  });

  /// Acquires the secondary receipt of one network, as the runtime does.
  Future<void> acquire(RecoverBullCutover owner) async {
    final admitted = await cutover.prepare();
    final admission =
        (admitted as Ok<RuntimeAdmission, LegacyImportFailure>).value;
    try {
      final backups = await RecoverBullWalletBackups.open(
        cutover: owner,
        admission: admission,
        legacy: legacy,
      );
      expect(backups, isA<Ok>());
      await (backups as Ok<RecoverBullWalletBackups, Failure>).value.close();
    } finally {
      await admission.close();
    }
  }

  Future<Result<void, LegacyImportFailure>> verify({
    RecoverBullCutover? second,
  }) async {
    final admission = await NativeFileGate(
      File('${directory.path}/coordination/lifecycle.lock'),
    ).acquire(exclusive: true, timeout: Duration.zero) as ExclusiveAdmission;
    try {
      return await RecoverBullRetirement(
        mainnet: mainnet,
        regtest: second ?? regtest,
      ).verifyRetirable(admission, origin: OwnerOrigin.fresh, source: legacy);
    } finally {
      await admission.close();
    }
  }

  test('no secondary receipt refuses', () async {
    final admitted = await cutover.prepare();
    await (admitted as Ok<RuntimeAdmission, LegacyImportFailure>).value.close();
    expect(await verify(), isA<Err>());
  });

  test('only the mainnet receipt refuses', () async {
    await acquire(mainnet);
    expect(await verify(), isA<Err>());
  });

  test('only the regtest receipt refuses', () async {
    await acquire(regtest);
    expect(await verify(), isA<Err>());
  });

  test('both receipts allow retirement', () async {
    await acquire(mainnet);
    await acquire(regtest);
    expect(await verify(), isA<Ok>());
  });
  test('two mainnet arguments never prove two networks', () async {
    await acquire(mainnet);
    expect(
      await verify(second: mainnet),
      isA<Err<void, LegacyImportFailure>>().having(
        (v) => v.failure,
        'failure',
        isA<LegacyImportVerificationFailed>(),
      ),
    );
  });

  test('two network labels cannot use one destination', () async {
    await acquire(mainnet);
    final alias = recoverBullCutoverForTesting(
      file: mainnet.file,
      standalone: mainnet.standalone,
      regtest: true,
    );
    expect(
      await verify(second: alias),
      isA<Err<void, LegacyImportFailure>>().having(
        (v) => v.failure,
        'failure',
        isA<LegacyImportVerificationFailed>(),
      ),
    );
  });
}
