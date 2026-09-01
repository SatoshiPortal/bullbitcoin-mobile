import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' hide ScriptType;
import 'package:recoverbull/recoverbull.dart';

import 'support/wallet_backup_behavior_harness.dart';

/// Product-level baseline for Bull backup.
///
/// These tests exercise the public backup facade against real state storage,
/// a real keychain manifest, real codecs and real encryption. Only the backup
/// server and the two section owners (external wallets, protected data) are
/// faked, because those are the process boundaries. Nothing here asserts on
/// how publication, recovery or fencing are wired internally, so the suite
/// stays meaningful across a refactor of that wiring.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('enabling automatic backup', () {
    test('publishes a first snapshot when the account has no backup', () async {
      final device = await _device();
      expect(device.remote.isEmpty, isTrue);

      expect(await device.facade.setEnabled(true), _succeeds);

      final state = await device.readState();
      expect(state.enabled, isTrue);
      expect(state.dirty, isFalse);
      expect(state.lastSucceededAt, isNotNull);
      expect(device.remote.isEmpty, isFalse);
      expect(device.remote.storeCount, 1);
    });

    test('recovers an existing backup for this seed, then publishes', () async {
      final server = FakeWalletBackupRemote();
      final firstDevice = await _device(remote: server);
      await _addWallet(firstDevice, walletId: 'cold-wallet', label: 'Cold');
      expect(await firstDevice.facade.setEnabled(true), _succeeds);
      expect(server.isEmpty, isFalse);

      final newDevice = await _device(remote: server);
      expect(await _wallets(newDevice), isEmpty);

      expect(await newDevice.facade.setEnabled(true), _succeeds);

      expect(
        (await _wallets(newDevice)).map((wallet) => wallet.label),
        contains('Cold'),
      );
      final state = await newDevice.readState();
      expect(state.enabled, isTrue);
      expect(state.dirty, isFalse);
      expect(state.lastSucceededAt, isNotNull);
    });

    test(
      'refuses a backup bound to another seed and leaves it alone',
      () async {
        final device = await _device();
        device.remote.install(await _foreignRootedBackup(device.encryptionKey));
        final published = device.remote.storedCiphertext;

        final result = await device.facade.setEnabled(true);

        expect(result, isA<Err<void, WalletBackupFailure>>());
        final state = await device.readState();
        expect(state.enabled, isFalse);
        expect(state.lastRecoveryStatus, WalletBackupRecoveryStatus.invalid);
        expect(device.remote.storedCiphertext, published);
        expect(device.remote.storeCount, 0);
      },
    );

    test('refuses a backup this wallet cannot read at all', () async {
      final server = FakeWalletBackupRemote();
      final otherWallet = await _device(
        remote: server,
        seed: backupSeed(
          mnemonic: foreignSeedMnemonic,
          fingerprint: foreignSeedFingerprint,
        ),
      );
      expect(await otherWallet.facade.setEnabled(true), _succeeds);
      final published = server.storedCiphertext;

      final device = await _device(remote: server);
      final result = await device.facade.setEnabled(true);

      expect(result, isA<Err<void, WalletBackupFailure>>());
      expect((await device.readState()).enabled, isFalse);
      expect(server.storedCiphertext, published);
    });
  });

  group('publishing local changes', () {
    test('a backup-relevant change republishes the backup', () async {
      final device = await _device();
      expect(await device.facade.setEnabled(true), _succeeds);
      final published = device.remote.storedCiphertext;
      final storesAfterEnabling = device.remote.storeCount;
      device.startCoordinator();

      await _addWallet(device, walletId: 'new-wallet', label: 'Savings');

      await settleUntil(
        () async => device.remote.storedCiphertext != published,
        description: 'a republished backup',
      );
      final state = await device.readState();
      expect(state.dirty, isFalse);
      expect(state.lastSucceededAt, isNotNull);
      expect(device.remote.storeCount, greaterThan(storesAfterEnabling));
    });

    test('an unavailable server keeps the backup pending until it is '
        'reachable again', () async {
      final device = await _device();
      expect(await device.facade.setEnabled(true), _succeeds);
      final published = device.remote.storedCiphertext;
      final publishedAt = (await device.readState()).lastSucceededAt;
      final storesAfterEnabling = device.remote.storeCount;

      device.remote.storeFailure = const WalletBackupRemoteUnavailableFailure();
      await _addWallet(device, walletId: 'offline-wallet', label: 'Offline');

      expect(
        await device.facade.backupNow(),
        isA<Err<void, WalletBackupFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletBackupRemoteUnavailableFailure>(),
        ),
      );
      var state = await device.readState();
      expect(state.dirty, isTrue);
      expect(state.lastSucceededAt, publishedAt);
      expect(device.remote.storedCiphertext, published);
      expect(device.remote.storeCount, storesAfterEnabling);

      device.remote.storeFailure = null;

      expect(await device.facade.backupNow(), _succeeds);
      state = await device.readState();
      expect(state.dirty, isFalse);
      expect(state.lastSucceededAt, isNotNull);
      expect(device.remote.storedCiphertext, isNot(published));
      expect(
        (await _wallets(device)).map((wallet) => wallet.label),
        contains('Offline'),
      );
    });
  });

  group('fencing publication', () {
    test('an interrupted recovery blocks publication until recovery '
        'completes', () async {
      final server = FakeWalletBackupRemote();
      final device = await _device(remote: server);
      expect(await device.facade.setEnabled(true), _succeeds);

      final otherDevice = await _device(remote: server);
      await _addWallet(otherDevice, walletId: 'elsewhere', label: 'Elsewhere');
      expect(await otherDevice.facade.setEnabled(true), _succeeds);
      final published = server.storedCiphertext;

      device.metadata.recoverComplete = false;
      final interrupted = await device.facade.recover();

      expect(interrupted.status, WalletBackupRecoveryStatus.partiallyRestored);
      expect((await device.readState()).recoveryBlocked, isTrue);
      expect(
        await device.facade.backupNow(),
        isA<Err<void, WalletBackupFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletBackupRecoveryBlockedFailure>(),
        ),
      );
      expect(server.storedCiphertext, published);

      device.metadata.recoverComplete = true;
      final finished = await device.facade.recover();

      expect(finished.status, WalletBackupRecoveryStatus.restored);
      expect((await device.readState()).recoveryBlocked, isFalse);
      expect(await device.facade.backupNow(), _succeeds);
    });

    test('a newer remote version blocks publication durably and is never '
        'overwritten', () async {
      final device = await _device();
      expect(await device.facade.setEnabled(true), _succeeds);
      final storesAfterEnabling = device.remote.storeCount;

      device.remote.install(await _backupFromTheFuture(device));
      final published = device.remote.storedCiphertext;
      await _addWallet(device, walletId: 'unpublishable', label: 'Pending');

      expect(await device.facade.backupNow(), _unsupportedVersion(2));
      expect((await device.readState()).unsupportedVersion, 2);
      expect(device.remote.storedCiphertext, published);

      expect(await device.facade.backupNow(), _unsupportedVersion(2));
      expect(device.remote.storedCiphertext, published);
      expect(device.remote.storeCount, storesAfterEnabling);
    });
  });

  group('backup files', () {
    test('an exported file matches the published backup exactly', () async {
      final device = await _device();
      await _addWallet(device, walletId: 'exported-wallet', label: 'Exported');
      expect(await device.facade.setEnabled(true), _succeeds);

      for (final protection in WalletBackupFileProtection.values) {
        final export = _value(
          await device.facade.buildExport(
            protection: protection,
            confirmedUnencrypted: true,
          ),
        );

        final comparison = _value(
          await device.facade.compareFile(export.copyBytes()),
        );

        expect(
          comparison.situation,
          WalletBackupImportSituation.same,
          reason: '$protection export should match the server',
        );
        expect(comparison.differences, isEmpty, reason: '$protection');
      }
    });

    test(
      'a file signed by another seed is rejected before comparison',
      () async {
        final device = await _device();
        expect(await device.facade.setEnabled(true), _succeeds);
        final otherWallet = await _device(
          seed: backupSeed(
            mnemonic: foreignSeedMnemonic,
            fingerprint: foreignSeedFingerprint,
          ),
        );
        final foreignFile = _value(
          await otherWallet.facade.buildExport(
            protection: WalletBackupFileProtection.unencrypted,
            confirmedUnencrypted: true,
          ),
        );

        expect(
          await device.facade.compareFile(foreignFile.copyBytes()),
          isA<Err<WalletBackupImportComparison, WalletBackupFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<WalletBackupInvalidEnvelopeFailure>(),
          ),
        );
      },
    );

    test('a modified readable backup is rejected before comparison', () async {
      final device = await _device();
      await _addWallet(device, walletId: 'signed-wallet', label: 'Original');
      final export = _value(
        await device.facade.buildExport(
          protection: WalletBackupFileProtection.unencrypted,
          confirmedUnencrypted: true,
        ),
      );
      final modified = utf8
          .decode(export.copyBytes())
          .replaceFirst('Original', 'Modified');

      expect(
        await device.facade.compareFile(
          Uint8List.fromList(utf8.encode(modified)),
        ),
        isA<Err<WalletBackupImportComparison, WalletBackupFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletBackupInvalidEnvelopeFailure>(),
        ),
      );
    });
  });
}

final Matcher _succeeds = isA<Ok<void, WalletBackupFailure>>();

Future<WalletBackupBehaviorHarness> _device({
  FakeWalletBackupRemote? remote,
  Seed? seed,
}) async {
  final harness = await WalletBackupBehaviorHarness.create(
    remote: remote,
    seed: seed,
  );
  addTearDown(harness.dispose);
  return harness;
}

/// Records an imported-mnemonic wallet, the cheapest backup-relevant change a
/// user can make that survives a recovery-inventory refresh.
Future<void> _addWallet(
  WalletBackupBehaviorHarness device, {
  required String walletId,
  required String label,
}) async {
  final result = await device.keychainManifest.recordWallet(
    parentFingerprint: device.fingerprint,
    wallet: KeychainManifestWalletInventoryBinding(
      walletId: walletId,
      seedFingerprint: Fingerprint(_seedFingerprintFor(walletId)),
      network: Network.bitcoinMainnet,
      scriptType: ScriptType.bip84,
      provenance: WalletProvenance.importedMnemonic,
      derivationPath: "m/84'/0'/0'",
      seedPassphraseUsed: false,
      label: label,
    ),
  );
  expect(result, isA<Ok<bool, KeychainManifestFailure>>());
}

Future<List<WalletBackupWalletSummary>> _wallets(
  WalletBackupBehaviorHarness device,
) async => _value(await device.facade.getContents()).wallets;

/// A backup that decrypts under [key] but declares another root, which is what
/// the client sees when the stored object does not belong to this wallet.
Future<WalletBackupCiphertext> _foreignRootedBackup(
  WalletBackupEncryptionKey key,
) async {
  final otherWallet = await _device(
    seed: backupSeed(
      mnemonic: foreignSeedMnemonic,
      fingerprint: foreignSeedFingerprint,
    ),
  );
  final export = _value(
    await otherWallet.facade.buildExport(
      protection: WalletBackupFileProtection.unencrypted,
      confirmedUnencrypted: true,
    ),
  );
  final root =
      jsonDecode(utf8.decode(export.copyBytes())) as Map<String, dynamic>
        ..remove('signature');
  final envelope = _value(
    otherWallet.encryption.decodeCanonical(
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(root))),
      expectedParentFingerprint: foreignSeedFingerprint,
    ),
  );
  return _value(otherWallet.encryption.encrypt(envelope: envelope, key: key));
}

/// This wallet's own backup, re-stamped with an envelope version no released
/// client understands, as a future release would leave it.
Future<WalletBackupCiphertext> _backupFromTheFuture(
  WalletBackupBehaviorHarness device,
) async {
  final export = _value(
    await device.facade.buildExport(
      protection: WalletBackupFileProtection.unencrypted,
      confirmedUnencrypted: true,
    ),
  );
  final root =
      jsonDecode(utf8.decode(export.copyBytes())) as Map<String, dynamic>
        ..remove('signature');
  final plaintext = jsonEncode(
    root,
  ).replaceFirst('"version":1,', '"version":2,');
  final backup = RecoverBull.createBackup(
    secret: utf8.encode(plaintext),
    backupKey: hex.decode(device.encryptionKey.hex),
  );
  return WalletBackupCiphertext(base64.encode(backup.ciphertext));
}

Matcher _unsupportedVersion(int version) =>
    isA<Err<void, WalletBackupFailure>>().having(
      (result) => result.failure,
      'failure',
      isA<WalletBackupUnsupportedEnvelopeVersionFailure>().having(
        (failure) => failure.version,
        'version',
        version,
      ),
    );

T _value<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('expected a value but got $failure'),
};

String _seedFingerprintFor(String walletId) =>
    walletId.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0');
