import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_apply.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';

final class LabelsBip329WalletMetadataContributor
    implements WalletMetadataRestoringContributor, WalletMetadataChangeSource {
  static const type = 'labels.bip329';
  static const version = 1;
  static const _globalScope = <String, Object?>{'kind': 'global'};
  static const _requiredPayloadKeys = {'type', 'ref', 'label'};
  static const _payloadKeys = {'type', 'ref', 'label', 'origin'};

  final LabelsFacade _labels;

  const LabelsBip329WalletMetadataContributor(this._labels);

  @override
  Stream<void> get changes => _labels.changes;

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
    if (record.scope.length != 1 || record.scope['kind'] != 'global') {
      return const WalletMetadataRecordInvalid(
        WalletMetadataRecordInvalidReason.invalidScope,
      );
    }
    final Bip329LabelRecord label;
    try {
      label = _labelFromPayload(record.payload);
    } on FormatException {
      return const WalletMetadataRecordInvalid(
        WalletMetadataRecordInvalidReason.invalidPayload,
      );
    }
    if (label.recordId != record.recordId) {
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
    final result = await _labels.exportBip329LabelRecords();
    return result.fold((labels) {
      try {
        final identities = <String>{};
        final records = labels
            .map((label) {
              if (!identities.add(label.recordId)) {
                throw const FormatException(
                  'Duplicate portable BIP329 label identity',
                );
              }
              return WalletMetadataRecord(
                type: type,
                version: version,
                scope: _globalScope,
                recordId: label.recordId,
                payload: _payloadFromLabel(label),
              );
            })
            .toList(growable: false);
        return Ok(List.unmodifiable(records));
      } on ArgumentError catch (_, st) {
        return _labelExportFailure(st);
      } on Exception catch (_, st) {
        return _labelExportFailure(st);
      }
    }, (_) => const Err(WalletMetadataBackupContributorFailure(type)));
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
      final records = intents
          .map((intent) {
            final record = intent.record;
            if (validateRecord(record) is! WalletMetadataRecordValid) {
              throw const FormatException('Invalid BIP329 recovery record');
            }
            return _labelFromPayload(record.payload);
          })
          .toList(growable: false);
      final result = await _labels.restoreBip329LabelRecords(records);
      return result.fold(
        (summary) => Ok(
          WalletMetadataContributorApplySummary(
            contributorType: type,
            intendedCount: summary.intendedCount,
            restoredCount: summary.restoredCount,
            alreadyPresentCount: summary.alreadyPresentCount,
            preservedLocalConflictCount: summary.preservedLocalConflictCount,
            deferredMissingWalletCount: 0,
            localProjectionMatchesSnapshot:
                summary.localProjectionMatchesSnapshot,
          ),
        ),
        (_) => const Err(WalletMetadataBackupContributorFailure(type)),
      );
    } on Exception catch (_, st) {
      log.severe(
        message: 'Failed to restore labels.bip329 metadata records',
        error: StateError('labels.bip329 restore failed'),
        trace: st,
      );
      return const Err(WalletMetadataBackupContributorFailure(type));
    }
  }
}

Result<List<WalletMetadataRecord>, WalletMetadataBackupFailure>
_labelExportFailure(StackTrace stack) {
  // Record values are private metadata and must never be logged.
  log.severe(
    message: 'Failed to build labels.bip329 metadata records',
    error: StateError('labels.bip329 record construction failed'),
    trace: stack,
  );
  return const Err(
    WalletMetadataBackupContributorFailure(
      LabelsBip329WalletMetadataContributor.type,
    ),
  );
}

Bip329LabelRecord _labelFromPayload(Map<String, Object?> payload) {
  final keys = payload.keys.toSet();
  if (!keys.containsAll(
        LabelsBip329WalletMetadataContributor._requiredPayloadKeys,
      ) ||
      keys.any(
        (key) =>
            !LabelsBip329WalletMetadataContributor._payloadKeys.contains(key),
      )) {
    throw const FormatException('Invalid BIP329 label record fields');
  }
  final type = payload['type'];
  final reference = payload['ref'];
  final label = payload['label'];
  final origin = payload['origin'];
  if (type is! String || reference is! String || label is! String) {
    throw const FormatException('Invalid BIP329 label record field types');
  }
  if (origin != null && origin is! String) {
    throw const FormatException('Invalid BIP329 label origin');
  }
  return Bip329LabelRecord(
    type: type,
    reference: reference,
    label: label,
    origin: origin as String?,
  );
}

Map<String, Object?> _payloadFromLabel(Bip329LabelRecord label) {
  return {
    'type': label.type,
    'ref': label.reference,
    'label': label.label,
    if (label.origin != null) 'origin': label.origin,
  };
}
