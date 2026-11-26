import 'dart:io';

import 'package:bull_recoverbull/storage.dart';
import 'package:bull_recoverbull/testing.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:legacy_storage/coordination.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

const _a = '01234567';
const _b = '89abcdef';
const _c = 'fedcba98';

/// The inventory guard exercised end to end with the real RecoverBull
/// projection of both network families and two (then three) seeds: the owner
/// of the inventory is judged by the proof the backup owner really stores.
void main() {
  // Mainnet and regtest deliberately use separate files.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory directory;
  late File secretsFile;
  late File mainFile;
  late File regtestFile;
  late RuntimeAdmission admission;
  late RecoverBullWalletBackups mainBackups;
  late RecoverBullWalletBackups regtestBackups;
  late RecoverBullWalletProperties properties;
  late SecretsInventory inventory;

  Future<SecretsInventory> open() async => _ok(
    await SecretsInventory.open(
      authority: SessionAuthority(),
      file: secretsFile,
      admission: admission,
      backupVerification: RecoverBullBackupVerification(
        backups: mainBackups,
        regtestBackups: regtestBackups,
      ),
    ),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('backup-guard-');
    addTearDown(() => directory.delete(recursive: true));
    File file(String name) => File('${directory.path}/$name.sqlite');
    secretsFile = file('secrets');
    mainFile = file('recoverbull');
    regtestFile = file('recoverbull_regtest');

    FakeSecureStoragePlatform().install();
    final main = recoverBullCutoverForTesting(
      file: mainFile,
      standalone: file('standalone'),
    );
    final regtest = recoverBullCutoverForTesting(
      file: regtestFile,
      standalone: file('standalone_regtest'),
      regtest: true,
    );
    final legacy = LegacySourceStore(
      source: LegacySource(file('legacy'), SqliteDatabase.currentSchemaVersion),
      create: SqliteDatabase.new,
    );
    final participants = [
      SecretsImport(file: secretsFile),
      main.participant,
      regtest.participant,
    ];
    admission = _ok(
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
    inventory = await open();
  });

  /// Registers a wallet the way provisioning does: the backup owner prepares
  /// its properties inside the inventory write.
  Future<Result<void, SecretFailure>> register(
    SecretsInventory target,
    String id,
    String seed,
  ) => target.registerWallet(
    _local(id, seed),
    prepareProperties: (existingSecretMember) async =>
        (await properties.prepareWallet(
          WalletPropertyDraft(
            id: id,
            network: BitcoinNetwork.mainnet,
            secretFingerprint: Fingerprint(seed),
            signerDevice: null,
            existingSecretMember: existingSecretMember,
          ),
        )).mapErr((_) => const StoreSecretFailure()),
  );

  Future<void> back(
    RecoverBullWalletBackups store,
    String id,
    String seed, {
    bool tested = true,
  }) async => _ok(
    await writeWalletBackupForTesting(store, (
      walletId: id,
      secretFingerprint: seed,
      encryptedVaultTested: false,
      physicalBackupTested: tested,
      latestEncryptedBackup: null,
      latestPhysicalBackup: null,
    )),
  );

  Future<void> twoSeeds() async {
    _ok(await register(inventory, 'wallet-a', _a));
    _ok(await register(inventory, 'wallet-b', _b));
    await back(mainBackups, 'wallet-a', _a);
  }

  group('protecting a view', () {
    test('adding an unbacked seed is refused, nothing is protected', () async {
      await twoSeeds();

      final refusal = _failure(await inventory.setCredential('1234'));
      expect(
        refusal,
        isA<BackupRequiredFailure>().having(
          (failure) => failure.missing.map((fingerprint) => fingerprint.hex),
          'missing',
          [_b],
        ),
      );
      expect(_ok(await inventory.isProtected()), isFalse);
      expect(_ok(await inventory.accessStatus()).failedAttempts, 0);
    });

    test('one proof in either store is enough, never two', () async {
      await twoSeeds();
      // The seed is the same on every network: a regtest proof counts.
      await back(regtestBackups, 'regtest-b', _b);

      _ok(await inventory.setCredential('1234'));
      expect(_ok(await inventory.isProtected()), isTrue);
      expect(_ok(await inventory.unbackedSecrets()), isEmpty);
    });

    test('a store that cannot be read is unavailable, not missing', () async {
      _ok(await register(inventory, 'wallet-a', _a));
      await back(mainBackups, 'wallet-a', _a);
      final other = openRecoverBullDatabaseForTesting(regtestFile.path);
      addTearDown(other.close);
      await other.customStatement('DROP TABLE recoverbull_wallet_backups');

      // A positive proof in the readable store still wins.
      expect(_ok(await inventory.unbackedSecrets()), isEmpty);

      // Without a proof, the unreadable store leaves the state unknown.
      _ok(await register(inventory, 'wallet-b', _b));
      expect(
        _failure(await inventory.setCredential('1234')),
        isA<BackupStateUnavailableFailure>(),
      );
      expect(_ok(await inventory.isProtected()), isFalse);
    });

    test('a watch-only view takes a PIN without a seed proof', () async {
      _ok(await inventory.registerWallet(_watchOnly('watch-only')));

      expect(_ok(await inventory.unbackedSecrets()), isEmpty);
      _ok(await inventory.setCredential('1234'));
      expect(_ok(await inventory.isProtected()), isTrue);
      // Protecting is not proof of a backup: the wallet has no usage row.
      expect(_ok(await mainBackups.read('watch-only')), isNull);
    });

    test('a BIP85 child follows the proof of its parent', () async {
      _ok(await register(inventory, 'wallet-a', _a));
      _ok(
        await inventory.reserveHexDerivation(
          parent: Fingerprint(_a),
          length: 16,
        ),
      );
      expect(
        _failure(await inventory.setCredential('1234')),
        isA<BackupRequiredFailure>(),
      );

      await back(mainBackups, 'wallet-a', _a);
      _ok(await inventory.setCredential('1234'));
    });
  });

  group('a protected view', () {
    Future<void> protectedWithA() async {
      _ok(await register(inventory, 'wallet-a', _a));
      await back(mainBackups, 'wallet-a', _a);
      _ok(await inventory.setCredential('1234'));
    }

    test('refuses a new seed without a backup and writes nothing', () async {
      await protectedWithA();

      expect(
        _failure(await register(inventory, 'wallet-c', _c)),
        isA<BackupRequiredFailure>(),
      );
      expect(_ok(await inventory.findWallet('wallet-c')), isNull);
      // The backup owner prepared nothing for the refused wallet.
      expect(_ok(await mainBackups.read('wallet-c')), isNull);
      expect(_ok(await inventory.unbackedSecrets()), isEmpty);
    });

    test('accepts a new seed that has a tested backup', () async {
      await protectedWithA();
      await back(mainBackups, 'earlier-c', _c);

      _ok(await register(inventory, 'wallet-c', _c));
      expect(_ok(await inventory.findWallet('wallet-c')), isNotNull);
    });

    test(
      'refuses when preparing the wallet would erase its only proof',
      () async {
        await protectedWithA();
        await back(mainBackups, 'wallet-c', _c);
        final before = _ok(await mainBackups.read('wallet-c'));

        expect(
          _failure(await register(inventory, 'wallet-c', _c)),
          isA<BackupRequiredFailure>(),
        );
        expect(_ok(await inventory.findWallet('wallet-c')), isNull);
        expect(_ok(await mainBackups.read('wallet-c')), before);
        expect(_ok(await inventory.unbackedSecrets()), isEmpty);
      },
    );

    test(
      'retains a proof with the same wallet id in the other store',
      () async {
        await protectedWithA();
        await back(mainBackups, 'wallet-c', _c);
        await back(regtestBackups, 'wallet-c', _c);
        _ok(await register(inventory, 'wallet-c', _c));
        expect(_ok(await inventory.unbackedSecrets()), isEmpty);
        expect(
          _ok(await mainBackups.read('wallet-c'))?.physicalBackupTested,
          isFalse,
        );
        expect(
          _ok(await regtestBackups.read('wallet-c'))?.physicalBackupTested,
          isTrue,
        );
      },
    );

    test(
      'retains a verified vault when replacing the matching usage',
      () async {
        await protectedWithA();
        await back(mainBackups, 'wallet-c', _c);
        final db = openRecoverBullDatabaseForTesting(mainFile.path);
        addTearDown(db.close);
        await db.customStatement(
          "INSERT INTO recoverbull_backup_status (network, fingerprint, vault_digest, verified_at) VALUES (?, ?, zeroblob(32), ?)",
          ['bitcoinMainnet', _c, '2026-01-01T00:00:00.000Z'],
        );
        _ok(await register(inventory, 'wallet-c', _c));
        expect(_ok(await inventory.unbackedSecrets()), isEmpty);
        expect(
          _ok(await mainBackups.read('wallet-c'))?.physicalBackupTested,
          isFalse,
        );
      },
    );

    test(
      'preserves the only proof when an existing member adds a wallet',
      () async {
        await protectedWithA();
        await back(mainBackups, 'wallet-a-two', _a);
        await back(mainBackups, 'wallet-a', _a, tested: false);
        final before = _ok(await mainBackups.read('wallet-a-two'));
        _ok(await register(inventory, 'wallet-a-two', _a));
        expect(_ok(await inventory.findWallet('wallet-a-two')), isNotNull);
        expect(_ok(await mainBackups.read('wallet-a-two')), before);
        expect(_ok(await inventory.unbackedSecrets()), isEmpty);
      },
    );

    test('a legacy unbacked member can add another wallet', () async {
      await protectedWithA();
      await back(mainBackups, 'wallet-a', _a, tested: false);
      _ok(await register(inventory, 'wallet-a-two', _a));
      expect(_ok(await inventory.findWallet('wallet-a-two')), isNotNull);
      expect(_ok(await inventory.unbackedSecrets()), [Fingerprint(_a)]);
    });

    test(
      'refuses an existing member wallet id owned by a different seed',
      () async {
        await protectedWithA();
        await back(mainBackups, 'earlier-b', _b);
        _ok(await register(inventory, 'wallet-b', _b));
        await back(mainBackups, 'wallet-a-two', _b);
        await back(mainBackups, 'earlier-b', _b, tested: false);
        final before = _ok(await mainBackups.read('wallet-a-two'));
        expect(
          _failure(await register(inventory, 'wallet-a-two', _a)),
          isA<BackupRequiredFailure>(),
        );
        expect(_ok(await inventory.findWallet('wallet-a-two')), isNull);
        expect(_ok(await mainBackups.read('wallet-a-two')), before);
        expect(_ok(await inventory.unbackedSecrets()), isEmpty);
      },
    );

    test(
      'the property owner refuses a conflicting identity with other proofs',
      () async {
        await protectedWithA();
        await back(mainBackups, 'wallet-a-two', _b);
        final before = _ok(await mainBackups.read('wallet-a-two'));
        expect(
          _failure(await register(inventory, 'wallet-a-two', _a)),
          isA<StoreSecretFailure>(),
        );
        expect(_ok(await inventory.findWallet('wallet-a-two')), isNull);
        expect(_ok(await mainBackups.read('wallet-a-two')), before);
        expect(_ok(await inventory.unbackedSecrets()), isEmpty);
      },
    );

    test(
      'refuses watch-only preparation that would erase a member proof',
      () async {
        await protectedWithA();
        await back(mainBackups, 'watch-only', _a);
        await back(mainBackups, 'wallet-a', _a, tested: false);
        final before = _ok(await mainBackups.read('watch-only'));
        final result = await inventory.registerWallet(
          _watchOnly('watch-only'),
          prepareProperties: (existingSecretMember) async =>
              (await properties.prepareWallet(
                const WalletPropertyDraft(
                  id: 'watch-only',
                  network: BitcoinNetwork.mainnet,
                  secretFingerprint: null,
                  signerDevice: null,
                ),
              )).mapErr((_) => const StoreSecretFailure()),
        );
        expect(_failure(result), isA<BackupRequiredFailure>());
        expect(_ok(await inventory.findWallet('watch-only')), isNull);
        expect(_ok(await mainBackups.read('watch-only')), before);
      },
    );

    test('accepts another wallet of a seed already in the view', () async {
      await protectedWithA();

      _ok(await register(inventory, 'wallet-a-two', _a));
      expect(_ok(await inventory.findWallet('wallet-a-two')), isNotNull);
    });

    test(
      'a PIN change needs no proof in a view that predates the rule',
      () async {
        await twoSeeds();
        await back(mainBackups, 'wallet-b', _b);
        _ok(await inventory.setCredential('1234'));
        // The backups are gone, as for a migrated view that never had a proof.
        await back(mainBackups, 'wallet-a', _a, tested: false);
        await back(mainBackups, 'wallet-b', _b, tested: false);
        expect(_ok(await inventory.unbackedSecrets()), hasLength(2));

        _ok(await inventory.setCredential('5678'));
        inventory.lock();
        expect(_ok(await inventory.unlock('1234')).accepted, isFalse);
        expect(_ok(await inventory.unlock('5678')).accepted, isTrue);
      },
    );
  });

  test('a member added while protecting never breaks the rule', () async {
    _ok(await register(inventory, 'wallet-a', _a));
    await back(mainBackups, 'wallet-a', _a);
    for (var round = 0; round < 8; round++) {
      final other = await open();
      final seed = (0x10000000 + round).toRadixString(16);
      final walletId = 'wallet-$round';
      final protectIndex = round.isOdd ? 0 : 1;
      final add = register(other, walletId, seed);
      final protect = inventory.setCredential('1234');
      List<Result<void, SecretFailure>> results;
      if (round.isOdd) {
        results = await Future.wait([protect, add]);
      } else {
        results = await Future.wait([add, protect]);
      }
      // A lock timeout between two connections fails closed; replay it
      // once the other side settled, then the guard alone decides.
      final settled = [
        for (final (index, result) in results.indexed)
          if (result case Err(failure: StoreSecretFailure()))
            await (index == protectIndex
                ? inventory.setCredential('1234')
                : register(other, walletId, seed))
          else
            result,
      ];
      // Exactly one side wins; the other is refused by the guard.
      expect(settled.whereType<Ok<void, SecretFailure>>(), hasLength(1));
      for (final result in settled) {
        if (result case Err(:final failure)) {
          expect(failure, isA<BackupRequiredFailure>());
        }
      }
      final protected = _ok(await inventory.isProtected());
      final unbacked = _ok(await inventory.unbackedSecrets());
      expect(
        protected && unbacked.isNotEmpty,
        isFalse,
        reason: 'round $round left a protected view with $unbacked',
      );
      await back(mainBackups, walletId, seed);
      if (protected) _ok(await inventory.removeCredential());
      await other.close();
    }
  });
}

RegisteredWallet _local(String id, String seed) => RegisteredWallet(
  id: id,
  secretFingerprint: seed,
  masterFingerprint: seed,
  signer: 'local',
  network: 'bitcoinMainnet',
  xpub: 'public-key-marker',
  externalDescriptor: 'wpkh([$seed/84h/0h/0h]public-key-marker/0/*)',
  internalDescriptor: 'wpkh(public-key-marker/1/*)',
  label: null,
  birthday: null,
  isDefault: false,
);

RegisteredWallet _watchOnly(String id) => RegisteredWallet(
  id: id,
  secretFingerprint: null,
  masterFingerprint: '',
  signer: 'none',
  network: 'bitcoinMainnet',
  xpub: 'public-key-marker',
  externalDescriptor: 'wpkh(public-key-marker/0/*)',
  internalDescriptor: 'wpkh(public-key-marker/1/*)',
  label: null,
  birthday: null,
  isDefault: false,
);

SecretFailure _failure<T>(Result<T, SecretFailure> result) =>
    result.fold((_) => fail('Expected a failure'), (failure) => failure);

T _ok<T, F extends Failure>(Result<T, F> result) => result.fold(
  (value) => value,
  (failure) => fail('Unexpected ${failure.runtimeType}'),
);
