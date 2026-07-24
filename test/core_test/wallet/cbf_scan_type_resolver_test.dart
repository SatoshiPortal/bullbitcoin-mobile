import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/cbf_scan_type_resolver.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';

/// A well-formed 64-hex-char fixture (32 sequential bytes 0x00..0x1f) — not
/// a real chain hash, just deterministic and easy to verify the length of.
const _fixtureBlockHash =
    '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';
const _fixtureBlockHeight = 0;

WalletBirthdayCheckpoint _buildCheckpoint({
  int blockHeight = _fixtureBlockHeight,
  String blockHash = _fixtureBlockHash,
}) {
  final now = DateTime.now().toUtc();
  return WalletBirthdayCheckpoint(
    requestedBirthday: now,
    blockTimestamp: now,
    blockHeight: blockHeight,
    blockHash: blockHash,
  );
}

WalletMetadataModel _buildMetadata({
  DateTime? syncedAt,
  int lastReceiveAddressIndex = 0,
  WalletBirthdayCheckpoint? checkpoint,
}) {
  const purpose = 84;
  final metadata = WalletMetadataModel(
    id: '[abcdef12/${purpose}h/0h/0h]',
    masterFingerprint: 'abcdef12',
    xpubFingerprint: '12345678',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'xpub-fake',
    externalPublicDescriptor: 'wpkh([abcdef12/${purpose}h/0h/0h]xpub-fake/0/*)',
    internalPublicDescriptor: 'wpkh([abcdef12/${purpose}h/0h/0h]xpub-fake/1/*)',
    signer: Signer.local,
    isDefault: false,
    syncedAt: syncedAt,
    lastReceiveAddressIndex: lastReceiveAddressIndex,
    // `birthdayCheckpoint` (used by the resolver) is only non-null once
    // both `birthday` and the three atomic `birthdayBlock*` fields are set
    // — see WalletMetadataModelBirthdayCheckpoint.birthdayCheckpoint.
    birthday: checkpoint?.requestedBirthday,
  );
  return checkpoint == null
      ? metadata
      : metadata.copyWithBirthdayCheckpoint(checkpoint);
}

void main() {
  const resolver = DefaultCbfScanTypeResolver();

  group('DefaultCbfScanTypeResolver.resolve — sync path', () {
    test('syncedAt set and the bdk.Wallet already has a real local chain tip '
        '(walletLatestCheckpointHeight > 0) uses SyncScanType', () {
      final metadata = _buildMetadata(syncedAt: DateTime.now().toUtc());

      final scanType = resolver.resolve(
        metadata,
        walletLatestCheckpointHeight: 800000,
      );

      expect(scanType, isA<bdk.SyncScanType>());
    });

    test('syncedAt null never uses SyncScanType, even if '
        'walletLatestCheckpointHeight happens to already be positive: a first '
        'sync must anchor on the persisted birthday checkpoint rather than an '
        'incidental local chain tip', () {
      final metadata = _buildMetadata(checkpoint: _buildCheckpoint());

      final scanType = resolver.resolve(
        metadata,
        walletLatestCheckpointHeight: 800000,
      );

      expect(scanType, isA<bdk.RecoveryScanType>());
    });
  });

  group('DefaultCbfScanTypeResolver.resolve — recovery path (first sync, '
      'syncedAt == null, walletLatestCheckpointHeight == 0)', () {
    test('a complete persisted birthday checkpoint resolves RecoveryScanType '
        'anchored at OtherRecoveryPoint(BlockId(height, BlockHash.fromString('
        'hash)))', () {
      final checkpoint = _buildCheckpoint(
        blockHeight: 820000,
        blockHash: _fixtureBlockHash,
      );
      final metadata = _buildMetadata(checkpoint: checkpoint);

      final scanType =
          resolver.resolve(metadata, walletLatestCheckpointHeight: 0)
              as bdk.RecoveryScanType;

      final recoveryPoint = scanType.checkpoint as bdk.OtherRecoveryPoint;
      expect(recoveryPoint.birthday.height, 820000);
      expect(
        recoveryPoint.birthday.hash,
        bdk.BlockHash.fromString(hex: _fixtureBlockHash),
      );
    });

    test('no persisted birthday checkpoint at all throws '
        'CbfMissingBirthdayCheckpointException rather than guessing a '
        'fallback recovery point', () {
      final metadata = _buildMetadata();

      expect(
        () => resolver.resolve(metadata, walletLatestCheckpointHeight: 0),
        throwsA(isA<CbfMissingBirthdayCheckpointException>()),
      );
    });

    test('usedScriptIndex floors to cbfMinimumRecoveryUsedScriptIndex when the '
        'stored lastReceiveAddressIndex is smaller (including the '
        'unset-import default of 0)', () {
      final metadata = _buildMetadata(
        lastReceiveAddressIndex: 0,
        checkpoint: _buildCheckpoint(),
      );

      final scanType =
          resolver.resolve(metadata, walletLatestCheckpointHeight: 0)
              as bdk.RecoveryScanType;

      expect(scanType.usedScriptIndex, cbfMinimumRecoveryUsedScriptIndex);
    });

    test('usedScriptIndex uses the stored lastReceiveAddressIndex when it '
        'exceeds cbfMinimumRecoveryUsedScriptIndex', () {
      final metadata = _buildMetadata(
        lastReceiveAddressIndex: 150,
        checkpoint: _buildCheckpoint(),
      );

      final scanType =
          resolver.resolve(metadata, walletLatestCheckpointHeight: 0)
              as bdk.RecoveryScanType;

      expect(scanType.usedScriptIndex, 150);
    });
  });

  group('DefaultCbfScanTypeResolver.resolve — anomalous case: syncedAt set but '
      "the wallet's own local BDK chain tip is missing "
      '(walletLatestCheckpointHeight == 0)', () {
    test('still resolves RecoveryScanType from the persisted checkpoint '
        'rather than trusting syncedAt alone', () {
      final metadata = _buildMetadata(
        syncedAt: DateTime.now().toUtc(),
        checkpoint: _buildCheckpoint(),
      );

      final scanType = resolver.resolve(
        metadata,
        walletLatestCheckpointHeight: 0,
      );

      expect(scanType, isA<bdk.RecoveryScanType>());
    });

    test('still throws CbfMissingBirthdayCheckpointException when no '
        'checkpoint is persisted — syncedAt being set is not treated as a '
        'trusted substitute for one', () {
      final metadata = _buildMetadata(syncedAt: DateTime.now().toUtc());

      expect(
        () => resolver.resolve(metadata, walletLatestCheckpointHeight: 0),
        throwsA(isA<CbfMissingBirthdayCheckpointException>()),
      );
    });
  });
}
