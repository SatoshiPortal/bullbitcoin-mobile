import 'dart:convert';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/bullvault_backup_entry.dart';
import '../../bullvault/bullvault_test_fixture.dart';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import '../backup_codec_fixture.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_ciphertext.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_metadata_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../backup_snapshot_fixture.dart';

class _Vaults extends Mock implements BullVaultFacade {}

T value<T>(Result<T, WalletBackupFailure> result) =>
    (result as Ok<T, WalletBackupFailure>).value;

void main() {
  final credential = BackupCredential.fromWords(backupFixtureWords);
  final vaults = _Vaults();
  final codec = backupCodecFixture(vaults);
  final snapshot = backupSnapshotFixture(credential);
  for (final populated in [true, false]) {
    test(
      'canonical ${populated ? 'full' : 'settings-only'} snapshot round trip preserves retained facts',
      () {
        final original = backupSnapshotFixture(
          credential,
          populated: populated,
        );
        final encoded = value(codec.encode(original));
        final decoded = value(codec.decode(encoded));
        expect(value(codec.encode(decoded)), encoded);
        expect(encoded, isNot(contains('"id":99')));
        expect(encoded, isNot(contains('isEncryptedVaultTested')));
        expect(decoded.metadata.settings.app.currency, 'CAD');
        expect(decoded.metadata.settings.mempool, hasLength(4));
        if (populated) {
          expect(decoded.manifest.derivations.single.alias, 'Child');
          expect(
            decoded.metadata.frozenOutputs.single.walletReference,
            'source-wallet',
          );
        }
      },
    );
  }
  test('row order and local label IDs do not change canonical content', () {
    final reordered = WalletBackupSnapshot(
      manifest: snapshot.manifest,
      vaults: [],
      metadata: WalletMetadataBackup(
        labels: snapshot.metadata.labels.reversed.toList(),
        frozenOutputs: snapshot.metadata.frozenOutputs,
        settings: snapshot.metadata.settings,
      ),
    );
    expect(
      value(codec.contentHash(snapshot)),
      value(codec.contentHash(reordered)),
    );
  });
  test(
    'authenticated encryption round trips with fresh nonces and stable content',
    () {
      final first = value(codec.encrypt(snapshot, credential));
      final second = value(codec.encrypt(snapshot, credential));
      expect(first.hash, isNot(second.hash));
      expect(
        value(codec.contentHash(value(codec.decrypt(first, credential)))),
        value(codec.contentHash(snapshot)),
      );
      final bytes = first.bytes;
      bytes[0] ^= 1;
      expect(first.bytes[0], isNot(bytes[0]));
      expect(
        codec.decrypt(WalletBackupCiphertext(bytes), credential),
        isA<Err>(),
      );
    },
  );
  test(
    'wrong words and mismatched identity never decode or encrypt successfully',
    () {
      final encrypted = value(codec.encrypt(snapshot, credential));
      final wrong = BackupCredential.fromWords(
        'legal winner thank year wave sausage worth useful legal winner thank yellow',
      );
      expect(codec.decrypt(encrypted, wrong), isA<Err>());
      expect(codec.encrypt(snapshot, wrong), isA<Err>());
    },
  );
  test(
    'malformed version, unknown fields, types and unsafe nesting fail without an Error',
    () {
      final data =
          jsonDecode(value(codec.encode(snapshot))) as Map<String, dynamic>;
      expect(codec.decode(jsonEncode({...data, 'version': 999})), isA<Err>());
      expect(
        codec.decode(jsonEncode({...data, 'seed': 'forbidden'})),
        isA<Err>(),
      );
      expect(codec.decode(jsonEncode({...data, 'inventory': 5})), isA<Err>());
      expect(codec.decode('${'[' * 5000}0${']' * 5000}'), isA<Err>());
      expect(
        codec.decode('x' * (WalletBackupCiphertext.maximumBytes + 1)),
        isA<Err>(),
      );
      expect(() => WalletBackupCiphertext([1, 2, 3]), throwsFormatException);
    },
  );
  test(
    'native vault package and signer annotations each have one owner in the wire format',
    () {
      final native = testBullVaultRecoveryPackageCodec();
      final package = native.decode(
        native.encode(
          testBullVaultRecoveryPackage(network: Network.bitcoinTestnet),
        ),
      );
      registerFallbackValue(package);
      when(() => vaults.encodeRecoveryPackage(any())).thenAnswer(
        (call) => native.encode(
          call.positionalArguments.single as BullVaultRecoveryPackage,
        ),
      );
      when(() => vaults.decodeRecoveryPackage(any())).thenAnswer(
        (call) => Ok(native.decode(call.positionalArguments.single as String)),
      );
      final minimal = backupSnapshotFixture(credential, populated: false);
      final signer = WalletSigner.single(
        masterFingerprint: 'aabbccdd',
        xpubFingerprint: '11223344',
        xpub: 'public-key',
        signer: SignerEntity.remote,
        signerDevice: SignerDeviceEntity.ledgerNanoX,
        registrationName: 'My Ledger',
      );
      final full = WalletBackupSnapshot(
        manifest: KeychainManifest(
          sourceFingerprint: minimal.manifest.sourceFingerprint,
          wallets: [
            BackupWallet(
              reference: 'vault-ref',
              network: package.policy.network,
              publicDescriptor: package.policy.descriptor,
              signers: [signer],
              isDefault: false,
              isHidden: true,
            ),
          ],
          derivations: [],
          nostrKeys: [],
          backupIdentities: minimal.manifest.backupIdentities,
        ),
        metadata: minimal.metadata,
        vaults: [
          BullVaultBackupEntry(
            reference: 'vault-ref',
            status: BullVaultLifecycleStatus.cancelled,
            recoveryPackage: package,
          ),
        ],
      );
      final encoded = value(codec.encode(full));
      final decoded = value(codec.decode(encoded));
      expect(value(codec.encode(decoded)), encoded);
      expect(
        decoded.manifest.wallets.single.signers.single.registrationName,
        'My Ledger',
      );
      expect(decoded.vaults.single.status, BullVaultLifecycleStatus.cancelled);
      expect('My Ledger'.allMatches(encoded), hasLength(1));
      expect(encoded, isNot(contains('serverTestedAt')));
    },
  );
  test('invalid catalog indices and paths reject before recovery', () {
    final data =
        jsonDecode(value(codec.encode(snapshot))) as Map<String, dynamic>;
    final inventory = data['inventory'] as Map<String, dynamic>;
    final derivation =
        (inventory['derivations'] as List).single as Map<String, dynamic>;
    derivation['index'] = -1;
    expect(codec.decode(jsonEncode(data)), isA<Err>());
    derivation['index'] = 5;
    derivation['path'] = "39'/999999999999999999999999'/5'";
    expect(codec.decode(jsonEncode(data)), isA<Err>());
  });
  test(
    'snapshot rejects dangling frozen and recipient references before any owner mutation',
    () {
      expect(
        () => WalletBackupSnapshot(
          manifest: KeychainManifest(
            sourceFingerprint: snapshot.manifest.sourceFingerprint,
            wallets: [],
            derivations: [],
            nostrKeys: [],
            backupIdentities: snapshot.manifest.backupIdentities,
          ),
          metadata: snapshot.metadata,
          vaults: [],
        ),
        throwsFormatException,
      );
    },
  );
}
