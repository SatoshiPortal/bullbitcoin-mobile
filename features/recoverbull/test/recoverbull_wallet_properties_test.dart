import 'dart:io';

import 'package:bull_recoverbull/storage.dart';
import 'package:bull_recoverbull/testing.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

void main() {
  // Mainnet and regtest deliberately use separate files.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late RecoverBullWalletBackups mainBackups;
  late RecoverBullWalletBackups regtestBackups;
  late RecoverBullWalletProperties properties;

  setUp(() async {
    final directory = await Directory.systemTemp.createTemp('wallet-backups-');
    addTearDown(() => directory.delete(recursive: true));
    File file(String name) => File('${directory.path}/$name.sqlite');

    FakeSecureStoragePlatform().install();
    final main = recoverBullCutoverForTesting(
      file: file('recoverbull'),
      standalone: file('standalone'),
    );
    final regtest = recoverBullCutoverForTesting(
      file: file('recoverbull_regtest'),
      standalone: file('standalone_regtest'),
      regtest: true,
    );
    final legacy = LegacySourceStore(
      source: LegacySource(file('legacy'), SqliteDatabase.currentSchemaVersion),
      create: SqliteDatabase.new,
    );
    final participants = [
      SecretsImport(file: file('secrets')),
      main.participant,
      regtest.participant,
    ];
    final admission = _ok(
      await StorageCutover(
        directory: Directory('${directory.path}/coordination'),
        legacy: legacy,
        expectedOwners: participants.map((owner) => owner.ownerId).toSet(),
        participants: participants,
      ).prepare(),
    );
    addTearDown(admission.close);
    mainBackups = _ok(
      await RecoverBullWalletBackups.open(
        cutover: main,
        admission: admission,
        legacy: legacy.source,
      ),
    );
    regtestBackups = _ok(
      await RecoverBullWalletBackups.open(
        cutover: regtest,
        admission: admission,
        legacy: legacy.source,
      ),
    );
    properties = RecoverBullWalletProperties(
      backups: mainBackups,
      regtestBackups: regtestBackups,
    );
  });

  test('a recreated wallet starts without any tested backup', () async {
    final draft = WalletPropertyDraft(
      id: 'wpkh([01234567/84h/1h/0h]):regtest',
      network: BitcoinNetwork.regtest,
      secretFingerprint: Fingerprint('01234567'),
      signerDevice: null,
    );
    _ok(
      await regtestBackups.write((
        walletId: draft.id,
        secretFingerprint: draft.secretFingerprint?.hex,
        encryptedVaultTested: true,
        physicalBackupTested: true,
        latestEncryptedBackup: 12,
        latestPhysicalBackup: 13,
      )),
    );

    _ok(await properties.prepareWallet(draft));

    final prepared = _ok(await regtestBackups.read(draft.id));
    expect(prepared?.encryptedVaultTested, isFalse);
    expect(prepared?.physicalBackupTested, isFalse);
    expect(prepared?.latestEncryptedBackup, isNull);
    expect(prepared?.latestPhysicalBackup, isNull);
    // The reset stays in the network's own store.
    expect(_ok(await mainBackups.read(draft.id)), isNull);
  });
}

T _ok<T, F extends Failure>(Result<T, F> result) => result.fold(
  (value) => value,
  (failure) => fail('Unexpected ${failure.runtimeType}'),
);
