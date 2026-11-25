import 'dart:io';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/storage.dart';
import 'package:bull_recoverbull/testing.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:legacy_storage/coordination.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

final class _Environment implements ActiveEnvironmentReader {
  _Environment(this.result);

  Result<Environment, PreferencesFailure> result;

  @override
  Future<Result<Environment, PreferencesFailure>>
  readActiveEnvironment() async {
    return result;
  }
}

void main() {
  // Mainnet and regtest deliberately use separate files.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SecretsInventory inventory;
  late RecoverBullWalletBackups mainBackups;
  late RecoverBullWalletBackups regtestBackups;
  late RecoverBullWalletProperties properties;
  late _Environment environment;
  late BackupStatus vaultStatus;
  late List<VaultContext> vaultReads;

  setUp(() async {
    environment = _Environment(const Ok(Environment.mainnet));
    vaultStatus = const BackupStatus();
    vaultReads = [];
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
    inventory = _ok(
      await SecretsInventory.open(file: file('secrets'), admission: admission),
    );
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
      environment: environment,
      vaultStatus: (context) async {
        vaultReads.add(context);
        return Ok(vaultStatus);
      },
    );
  });

  Future<WalletRegistration> registerWallet({
    bool regtest = false,
    bool isDefault = true,
  }) async {
    final origin = regtest ? '01234567/84h/1h/0h' : '01234567/84h/0h/0h';
    final id = 'wpkh([$origin])${regtest ? ':regtest' : ''}';
    _ok(
      await inventory.registerWallet(
        RegisteredWallet(
          id: id,
          secretFingerprint: '01234567',
          masterFingerprint: '01234567',
          signer: 'local',
          network: regtest ? 'bitcoinRegtest' : 'bitcoinMainnet',
          xpub: 'public-key-marker',
          externalDescriptor: 'wpkh([$origin]public-key-marker/0/*)',
          internalDescriptor: 'wpkh(public-key-marker/1/*)',
          label: null,
          birthday: null,
          isDefault: isDefault,
        ),
      ),
    );
    return _ok(await inventory.readWallet(id));
  }

  test('accepts a tested physical backup for the mainnet default', () async {
    final wallet = await registerWallet();
    _ok(await mainBackups.write(_backup(wallet, physical: true)));

    expect(_ok(await properties.hasVerifiedBackups([wallet])), isTrue);
    expect(vaultReads, isEmpty);
  });

  test('reads regtest backup facts only from the regtest store', () async {
    environment.result = const Ok(Environment.regtest);
    final wallet = await registerWallet(regtest: true);
    _ok(await mainBackups.write(_backup(wallet, physical: true)));

    expect(_ok(await properties.hasVerifiedBackups([wallet])), isFalse);
    expect(vaultReads.single.network, BitcoinNetwork.regtest);
    vaultReads.clear();

    _ok(await regtestBackups.write(_backup(wallet, encrypted: true)));
    expect(_ok(await properties.hasVerifiedBackups([wallet])), isTrue);
    expect(vaultReads, isEmpty);
  });

  test('ignores a backed-up default from another environment', () async {
    environment.result = const Ok(Environment.regtest);
    final wallet = await registerWallet();
    _ok(await regtestBackups.write(_backup(wallet, physical: true)));
    vaultStatus = BackupStatus(verifiedAt: DateTime.utc(2026));

    expect(_ok(await properties.hasVerifiedBackups([wallet])), isFalse);
    expect(vaultReads, isEmpty);
  });

  for (final verified in [true, false]) {
    test(
      'uses the vault verification status when verified is $verified',
      () async {
        final wallet = await registerWallet();
        _ok(await mainBackups.write(_backup(wallet)));
        final date = DateTime.utc(2026);
        vaultStatus = BackupStatus(
          storedAt: date,
          verifiedAt: verified ? date : null,
        );

        expect(_ok(await properties.hasVerifiedBackups([wallet])), verified);
        expect(vaultReads.single.fingerprint, wallet.secretFingerprint);
        expect(vaultReads.single.network, BitcoinNetwork.mainnet);
      },
    );
  }

  test('refuses an inventory with no default wallet', () async {
    final wallet = await registerWallet(isDefault: false);
    _ok(await mainBackups.write(_backup(wallet, physical: true)));

    expect(_ok(await inventory.hasVerifiedBackups(properties)), isFalse);
    expect(vaultReads, isEmpty);
  });

  test(
    'returns a fetch failure when Preferences cannot read the environment',
    () async {
      final wallet = await registerWallet();
      _ok(await mainBackups.write(_backup(wallet, physical: true)));
      environment.result = const Err(PreferencesReadFailure());

      expect(
        await properties.hasVerifiedBackups([wallet]),
        isA<Err<bool, SecretFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<FetchSecretFailure>(),
        ),
      );
      expect(vaultReads, isEmpty);
    },
  );

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

WalletBackupUsage _backup(
  WalletRegistration wallet, {
  bool physical = false,
  bool encrypted = false,
}) => (
  walletId: wallet.id,
  secretFingerprint: wallet.secretFingerprint?.hex,
  encryptedVaultTested: encrypted,
  physicalBackupTested: physical,
  latestEncryptedBackup: null,
  latestPhysicalBackup: null,
);

T _ok<T, F extends Failure>(Result<T, F> result) => result.fold(
  (value) => value,
  (failure) => fail('Unexpected ${failure.runtimeType}'),
);
