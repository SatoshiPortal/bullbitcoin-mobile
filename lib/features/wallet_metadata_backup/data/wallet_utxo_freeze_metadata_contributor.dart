import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_frozen_wallet_outpoints_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/restore_frozen_wallet_outpoints_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_utxo_freeze_changes_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_apply.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';

final class WalletUtxoFreezeMetadataContributor
    implements WalletMetadataRestoringContributor, WalletMetadataChangeSource {
  static const type = 'wallet.utxo_freeze';
  static const version = 1;

  final GetFrozenWalletOutpointsUsecase _getFrozenOutpoints;
  final RestoreFrozenWalletOutpointsUsecase _restoreFrozenOutpoints;
  final WatchWalletUtxoFreezeChangesUsecase _watchChanges;

  const WalletUtxoFreezeMetadataContributor(
    this._getFrozenOutpoints,
    this._restoreFrozenOutpoints,
    this._watchChanges,
  );

  @override
  Stream<void> get changes => _watchChanges.execute();

  @override
  String get recordType => type;

  @override
  Set<int> get supportedVersions => const {version};

  @override
  WalletMetadataRecordValidation validateRecord(WalletMetadataRecord record) {
    if (record.type != type || record.version != version) {
      return const WalletMetadataRecordInvalid(
        WalletMetadataRecordInvalidReason.unsupportedTypeOrVersion,
      );
    }
    final payload = record.payload;
    if (payload.keys.toSet().length != 4 ||
        !payload.keys.toSet().containsAll(const {
          'walletRef',
          'txid',
          'vout',
          'frozen',
        })) {
      return const WalletMetadataRecordInvalid(
        WalletMetadataRecordInvalidReason.invalidPayload,
      );
    }
    final walletRef = payload['walletRef'];
    final txid = payload['txid'];
    final vout = payload['vout'];
    if (walletRef is! String ||
        txid is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(txid) ||
        vout is! int ||
        vout < 0 ||
        vout > 0xffffffff ||
        payload['frozen'] != true) {
      return const WalletMetadataRecordInvalid(
        WalletMetadataRecordInvalidReason.invalidPayload,
      );
    }
    final expectedScope = walletRef.isEmpty
        ? const <String, Object?>{'kind': 'unattributed'}
        : <String, Object?>{'kind': 'wallet', 'walletRef': walletRef};
    if (!_sameObject(record.scope, expectedScope)) {
      return const WalletMetadataRecordInvalid(
        WalletMetadataRecordInvalidReason.invalidScope,
      );
    }
    if (record.recordId != '$txid:$vout') {
      return const WalletMetadataRecordInvalid(
        WalletMetadataRecordInvalidReason.invalidIdentity,
      );
    }
    return WalletMetadataRecordValid(
      WalletMetadataImportIntent(contributorType: type, record: record),
    );
  }

  @override
  Future<Result<List<WalletMetadataRecord>, WalletMetadataBackupFailure>>
  exportRecords() async {
    try {
      final freezes = await _getFrozenOutpoints.execute();
      final identities = <String>{};
      final records = freezes
          .map((freeze) {
            final record = _toRecord(freeze);
            if (!identities.add(record.identity)) {
              throw const FormatException(
                'Duplicate wallet UTXO freeze identity',
              );
            }
            return record;
          })
          .toList(growable: false);
      return Ok(List.unmodifiable(records));
    } on ArgumentError catch (_, st) {
      return _freezeFailure('export', st);
    } on Exception catch (_, st) {
      return _freezeFailure('export', st);
    }
  }

  @override
  Future<
    Result<WalletMetadataContributorApplySummary, WalletMetadataBackupFailure>
  >
  applyIntents({
    required List<WalletMetadataImportIntent> intents,
    required WalletMetadataApplyContext context,
  }) async {
    try {
      final desired = intents
          .map((intent) => _fromRecord(intent.record))
          .toList(growable: false);
      final desiredKeys = desired.map(_freezeKey).toSet();
      if (desiredKeys.length != desired.length) {
        throw const FormatException('Duplicate freeze recovery intent');
      }
      final existing = await _getFrozenOutpoints.execute();
      final existingKeys = existing.map(_freezeKey).toSet();
      final alreadyPresentCount = desiredKeys
          .where(existingKeys.contains)
          .length;
      await _restoreFrozenOutpoints.execute(desired);
      return Ok(
        WalletMetadataContributorApplySummary(
          contributorType: type,
          intendedCount: intents.length,
          restoredCount: intents.length - alreadyPresentCount,
          alreadyPresentCount: alreadyPresentCount,
          preservedLocalConflictCount: 0,
          deferredMissingWalletCount: 0,
          localProjectionMatchesSnapshot: true,
        ),
      );
    } on ArgumentError catch (_, st) {
      return _freezeFailure('restore', st);
    } on Exception catch (_, st) {
      return _freezeFailure('restore', st);
    }
  }

  FrozenWalletOutpoint _fromRecord(WalletMetadataRecord record) {
    if (validateRecord(record) is! WalletMetadataRecordValid) {
      throw const FormatException('Invalid freeze recovery record');
    }
    return FrozenWalletOutpoint(
      walletId: record.payload['walletRef']! as String,
      txId: record.payload['txid']! as String,
      vout: record.payload['vout']! as int,
    );
  }

  WalletMetadataRecord _toRecord(FrozenWalletOutpoint freeze) {
    return WalletMetadataRecord(
      type: type,
      version: version,
      scope: freeze.isAttributed
          ? {'kind': 'wallet', 'walletRef': freeze.walletId}
          : const {'kind': 'unattributed'},
      recordId: '${freeze.txId}:${freeze.vout}',
      payload: {
        'walletRef': freeze.walletId,
        'txid': freeze.txId,
        'vout': freeze.vout,
        'frozen': true,
      },
    );
  }
}

Result<T, WalletMetadataBackupFailure> _freezeFailure<T>(
  String operation,
  StackTrace stack,
) {
  // Wallet ids and outpoints are private metadata and are never logged.
  log.severe(
    message: 'Failed to $operation wallet.utxo_freeze metadata records',
    error: StateError('wallet.utxo_freeze $operation failed'),
    trace: stack,
  );
  return const Err(
    WalletMetadataBackupContributorFailure(
      WalletUtxoFreezeMetadataContributor.type,
    ),
  );
}

({String walletId, String txId, int vout}) _freezeKey(
  FrozenWalletOutpoint freeze,
) => (walletId: freeze.walletId, txId: freeze.txId, vout: freeze.vout);

bool _sameObject(Map<String, Object?> left, Map<String, Object?> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}
