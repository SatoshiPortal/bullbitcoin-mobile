import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/storage.dart';
import 'package:bull_recoverbull/testing.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';
import 'package:signers/storage.dart';
import 'package:sync/storage.dart';

void main() {
  // Mainnet and regtest deliberately use separate files and executors.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late SecretsInventory inventory;
  late RecoverBullWalletBackups mainBackups;
  late RecoverBullWalletBackups regtestBackups;
  late SecretsWalletRegistrations registrations;
  late Result<Environment, PreferencesFailure> environment;
  late BackupStatus vaultStatus;
  late List<VaultContext> vaultReads;

  setUp(() async {
    environment = const Ok(Environment.mainnet);
    vaultStatus = const BackupStatus();
    vaultReads = [];
    final directory = await Directory.systemTemp.createTemp('wallet-backups-');
    addTearDown(() => directory.delete(recursive: true));
    File file(String name) => File('${directory.path}/$name.sqlite');

    FakeSecureStoragePlatform().install();
    final secrets = Secrets(scratchDirectory: () async => directory.path);
    final signerKeys = secrets.databaseKeys(module: 'signers');
    final syncKeys = secrets.databaseKeys(module: 'sync');
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
      signersWalletMetadataImport(file: file('signers'), keys: signerKeys),
      syncWalletMetadataImport(file: file('sync'), keys: syncKeys),
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
    final signers = _ok(
      await SignerDevices.open(
        file: file('signers'),
        admission: admission,
        keys: signerKeys,
      ),
    );
    final sync = _ok(
      await SyncFreshness.open(
        file: file('sync'),
        admission: admission,
        keys: syncKeys,
      ),
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
    registrations = SecretsWalletRegistrations(
      inventory,
      signers,
      sync,
      mainBackups,
      regtestBackups,
      () async => environment,
      (context) async {
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

    expect(_ok(await registrations.hasVerifiedBackups([wallet])), isTrue);
    expect(vaultReads, isEmpty);
  });

  test('reads regtest backup facts only from the regtest store', () async {
    environment = const Ok(Environment.regtest);
    final wallet = await registerWallet(regtest: true);
    _ok(await mainBackups.write(_backup(wallet, physical: true)));

    expect(_ok(await registrations.hasVerifiedBackups([wallet])), isFalse);
    expect(vaultReads.single.network, BitcoinNetwork.regtest);
    vaultReads.clear();

    _ok(await regtestBackups.write(_backup(wallet, encrypted: true)));
    expect(_ok(await registrations.hasVerifiedBackups([wallet])), isTrue);
    expect(vaultReads, isEmpty);
  });

  test('ignores a backed-up default from another environment', () async {
    environment = const Ok(Environment.regtest);
    final wallet = await registerWallet();
    _ok(await regtestBackups.write(_backup(wallet, physical: true)));
    vaultStatus = BackupStatus(verifiedAt: DateTime.utc(2026));

    expect(_ok(await registrations.hasVerifiedBackups([wallet])), isFalse);
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

        expect(_ok(await registrations.hasVerifiedBackups([wallet])), verified);
        expect(vaultReads.single.fingerprint, wallet.secretFingerprint);
        expect(vaultReads.single.network, BitcoinNetwork.mainnet);
      },
    );
  }

  test('refuses an inventory with no default wallet', () async {
    final wallet = await registerWallet(isDefault: false);
    _ok(await mainBackups.write(_backup(wallet, physical: true)));

    expect(_ok(await inventory.hasVerifiedBackups(registrations)), isFalse);
    expect(vaultReads, isEmpty);
  });

  test(
    'returns a fetch failure when Preferences cannot read the environment',
    () async {
      final wallet = await registerWallet();
      _ok(await mainBackups.write(_backup(wallet, physical: true)));
      environment = const Err(PreferencesReadFailure());

      expect(
        await registrations.hasVerifiedBackups([wallet]),
        isA<Err<bool, SecretFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<FetchSecretFailure>(),
        ),
      );
      expect(vaultReads, isEmpty);
    },
  );
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
