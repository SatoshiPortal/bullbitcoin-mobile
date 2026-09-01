import 'dart:convert';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' hide ScriptType;
import 'package:recoverbull/recoverbull.dart';

import 'support/wallet_backup_behavior_harness.dart';

/// Bull backup is an authoritative snapshot: a publication replaces the whole
/// remote object and nothing is merged into it, so deletion is by omission.
///
/// These tests read the bytes the server actually holds, because the point of
/// snapshot semantics is what a second installation would recover — not what
/// the publishing device believes it sent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('deletion by omission', () {
    test('a forgotten wallet leaves the remote snapshot and never '
        'comes back', () async {
      final server = FakeWalletBackupRemote();
      final device = await _device(remote: server);
      await _addWallet(device, walletId: 'forgotten', label: 'Forgotten');
      expect(await device.facade.setEnabled(true), _succeeds);
      expect(_published(device), contains('forgotten'));

      expect(
        await device.keychainManifest.deleteWallet(
          parentFingerprint: device.fingerprint,
          walletId: 'forgotten',
        ),
        isA<Ok<void, KeychainManifestFailure>>(),
      );
      expect(await device.facade.backupNow(), _succeeds);

      expect(_published(device), isNot(contains('forgotten')));
      final replacement = await _device(remote: server);
      expect(await replacement.facade.setEnabled(true), _succeeds);
      expect(
        (await _wallets(replacement)).map((wallet) => wallet.label),
        isNot(contains('Forgotten')),
      );
    });

    test('deleting the last external wallet publishes a document without '
        'the definitions section', () async {
      final device = await _device();
      device.definitions.definitions = [
        WalletDefinition(
          walletRef: 'external-wallet',
          network: Network.bitcoinMainnet,
          descriptor: _externalDescriptor,
          signerDevice: SignerDeviceEntity.ledgerNanoX,
          birthday: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
          provenance: WalletProvenance.externalSigner,
        ),
      ];
      expect(await device.facade.setEnabled(true), _succeeds);
      expect(_publishedDocument(device), contains('definitions'));

      device.definitions.definitions = const [];
      expect(await device.facade.backupNow(), _succeeds);

      expect(_publishedDocument(device), isNot(contains('definitions')));
      expect(_published(device), isNot(contains('86241f88')));
    });
  });

  group('head conflict', () {
    test('a stale installation stops at needs-attention and leaves the '
        'remote alone', () async {
      final server = FakeWalletBackupRemote();
      final device = await _device(remote: server);
      expect(await device.facade.setEnabled(true), _succeeds);

      final elsewhere = await _device(remote: server);
      await _addWallet(elsewhere, walletId: 'elsewhere', label: 'Elsewhere');
      expect(await elsewhere.facade.setEnabled(true), _succeeds);
      final published = server.storedCiphertext;
      final storesBefore = server.storeCount;

      await _addWallet(device, walletId: 'stale', label: 'Stale');
      final result = await device.facade.backupNow();

      expect(
        result,
        isA<Err<void, WalletBackupFailure>>().having(
          (value) => value.failure,
          'failure',
          isA<WalletBackupHeadConflictFailure>(),
        ),
      );
      expect(server.storedCiphertext, published);
      expect(server.storeCount, storesBefore);
      final state = await device.readState();
      expect(state.needsAttention, isTrue);
      expect(state.recoveryBlocked, isTrue);
      expect(state.dirty, isTrue, reason: 'local work must survive a conflict');
      expect(state.remoteCheckpoint?.generation, storesBefore);
    });

    test('recovering resolves the conflict and publication resumes', () async {
      final server = FakeWalletBackupRemote();
      final device = await _device(remote: server);
      expect(await device.facade.setEnabled(true), _succeeds);

      final elsewhere = await _device(remote: server);
      await _addWallet(elsewhere, walletId: 'elsewhere', label: 'Elsewhere');
      expect(await elsewhere.facade.setEnabled(true), _succeeds);

      await _addWallet(device, walletId: 'stale', label: 'Stale');
      expect(await device.facade.backupNow(), isA<Err<void, Failure>>());

      expect(
        (await device.facade.recover()).status,
        WalletBackupRecoveryStatus.restored,
      );
      expect((await device.readState()).recoveryBlocked, isFalse);

      expect(await device.facade.backupNow(), _succeeds);
      expect(_published(device), contains('elsewhere'));
      expect(_published(device), contains('stale'));
    });
  });

  test('a routine publication stores against its checkpoint without '
      'fetching', () async {
    final device = await _device();
    expect(await device.facade.setEnabled(true), _succeeds);
    final fetchesAfterEnabling = device.remote.fetchCount;
    expect((await device.readState()).remoteCheckpoint, isNotNull);

    await _addWallet(device, walletId: 'routine', label: 'Routine');
    expect(await device.facade.backupNow(), _succeeds);

    expect(device.remote.fetchCount, fetchesAfterEnabling);
    expect(_published(device), contains('routine'));
  });
}

const _externalDescriptor =
    'wpkh([86241f88/84h/0h/0h]xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8Jfu'
    'DwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7/<0;1>/*)'
    '#n8txaeah';

final Matcher _succeeds = isA<Ok<void, WalletBackupFailure>>();

Future<WalletBackupBehaviorHarness> _device({
  FakeWalletBackupRemote? remote,
}) async {
  final harness = await WalletBackupBehaviorHarness.create(remote: remote);
  addTearDown(harness.dispose);
  return harness;
}

Future<void> _addWallet(
  WalletBackupBehaviorHarness device, {
  required String walletId,
  required String label,
}) async {
  final result = await device.keychainManifest.recordWallet(
    parentFingerprint: device.fingerprint,
    wallet: KeychainManifestWalletInventoryBinding(
      walletId: walletId,
      seedFingerprint: Fingerprint(
        walletId.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0'),
      ),
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
) async => switch (await device.facade.getContents()) {
  Ok(:final value) => value.wallets,
  Err(:final failure) => fail('backup contents unavailable: $failure'),
};

/// The plaintext the server is holding right now, decrypted with this device's
/// backup key exactly as another installation would.
String _published(WalletBackupBehaviorHarness device) {
  final ciphertext = device.remote.storedCiphertext;
  if (ciphertext == null) fail('nothing has been published');
  return utf8.decode(
    RecoverBull.restoreBackup(
      backup: BullBackup(
        createdAt: 0,
        id: const [],
        ciphertext: base64.decode(ciphertext),
        salt: const [],
      ),
      backupKey: hex.decode(device.encryptionKey.hex),
    ),
  );
}

/// The published document's top-level keys, so a test can assert that a whole
/// section is absent rather than merely empty.
Set<String> _publishedDocument(WalletBackupBehaviorHarness device) =>
    (jsonDecode(_published(device)) as Map<String, Object?>).keys.toSet();
