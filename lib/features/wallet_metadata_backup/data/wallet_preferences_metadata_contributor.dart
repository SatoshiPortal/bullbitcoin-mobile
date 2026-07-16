import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_recovered_wallet_preferences_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_preferences_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_preference_changes_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_apply.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_contributor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_preferences_restore_policy.dart';

final class WalletPreferencesMetadataContributor
    implements WalletMetadataRestoringContributor, WalletMetadataChangeSource {
  static const type = 'wallet.preferences';
  static const version = 1;

  final GetWalletPreferencesUsecase _getPreferences;
  final ApplyRecoveredWalletPreferencesUsecase _applyPreferences;
  final WatchWalletPreferenceChangesUsecase _watchChanges;

  const WalletPreferencesMetadataContributor(
    this._getPreferences,
    this._applyPreferences,
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
    const allowedKeys = {
      'walletRef',
      'label',
      'hideOnHome',
      'autoSweepEnabled',
    };
    final walletRef = payload['walletRef'];
    final label = payload['label'];
    final hideOnHome = payload['hideOnHome'];
    final autoSweepEnabled = payload['autoSweepEnabled'];
    if (payload.keys.any((key) => !allowedKeys.contains(key)) ||
        walletRef is! String ||
        walletRef.isEmpty ||
        (payload.containsKey('label') && label is! String) ||
        (payload.containsKey('hideOnHome') && hideOnHome is! bool) ||
        (payload.containsKey('autoSweepEnabled') &&
            autoSweepEnabled is! bool) ||
        !payload.keys.any(
          (key) =>
              key == 'label' ||
              key == 'hideOnHome' ||
              key == 'autoSweepEnabled',
        )) {
      return const WalletMetadataRecordInvalid(
        WalletMetadataRecordInvalidReason.invalidPayload,
      );
    }
    if (record.scope.length != 2 ||
        record.scope['kind'] != 'wallet' ||
        record.scope['walletRef'] != walletRef) {
      return const WalletMetadataRecordInvalid(
        WalletMetadataRecordInvalidReason.invalidScope,
      );
    }
    if (record.recordId != 'preferences') {
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
    final result = await _getPreferences.execute();
    return result.fold((preferences) {
      try {
        final identities = <String>{};
        final records = preferences
            .where((preference) => preference.hasRepresentedValue)
            .map((preference) {
              final record = _toRecord(preference);
              if (!identities.add(record.identity)) {
                throw const FormatException(
                  'Duplicate wallet preference identity',
                );
              }
              return record;
            })
            .toList(growable: false);
        return Ok(List.unmodifiable(records));
      } on ArgumentError catch (_, st) {
        return _preferencesFailure('build', st);
      } on Exception catch (_, st) {
        return _preferencesFailure('build', st);
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
    final currentResult = await _getPreferences.execute();
    final List<WalletPreferences> current;
    switch (currentResult) {
      case Ok(:final value):
        current = value;
      case Err():
        return const Err(WalletMetadataBackupContributorFailure(type));
    }
    try {
      final desired = intents
          .map((intent) => _fromRecord(intent.record))
          .toList(growable: false);
      final desiredByWallet = {
        for (final preference in desired) preference.walletRef: preference,
      };
      if (desiredByWallet.length != desired.length) {
        throw const FormatException(
          'Duplicate wallet preference recovery intent',
        );
      }
      final currentByWallet = {
        for (final preference in current) preference.walletRef: preference,
      };
      final toApply = <WalletPreferences>[];
      var restoredCount = 0;
      var alreadyPresentCount = 0;
      var conflictCount = 0;
      var deferredCount = 0;
      for (final preference in desired) {
        final existing = currentByWallet[preference.walletRef];
        final disposition = WalletPreferencesRestorePolicy.classify(
          walletExists: existing != null,
          createdInRecovery: context.createdWalletRefs.contains(
            preference.walletRef,
          ),
        );
        switch (disposition) {
          case WalletPreferencesRestoreDisposition.applyToCreatedWallet:
            toApply.add(preference);
            if (_samePreferences(existing!, preference)) {
              alreadyPresentCount++;
            } else {
              restoredCount++;
            }
          case WalletPreferencesRestoreDisposition.conflictWithExistingWallet:
            conflictCount++;
          case WalletPreferencesRestoreDisposition.deferredMissingWallet:
            deferredCount++;
        }
      }
      final applyResult = await _applyPreferences.execute(toApply);
      if (applyResult case Err()) {
        return const Err(WalletMetadataBackupContributorFailure(type));
      }

      final projected = Map<String, WalletPreferences>.of(currentByWallet);
      for (final preference in toApply) {
        projected[preference.walletRef] = preference;
      }
      final projectedRecords = projected.values
          .where((preference) => preference.hasRepresentedValue)
          .map(_toRecord)
          .toList(growable: false);
      final desiredRecords = intents
          .map((intent) => intent.record)
          .toList(growable: false);
      return Ok(
        WalletMetadataContributorApplySummary(
          contributorType: type,
          intendedCount: intents.length,
          restoredCount: restoredCount,
          alreadyPresentCount: alreadyPresentCount,
          preservedLocalConflictCount: conflictCount,
          deferredMissingWalletCount: deferredCount,
          localProjectionMatchesSnapshot: _sameRecordProjection(
            projectedRecords,
            desiredRecords,
            hasConflicts: conflictCount > 0 || deferredCount > 0,
          ),
        ),
      );
    } on ArgumentError catch (_, st) {
      return _preferencesFailure('restore', st);
    } on Exception catch (_, st) {
      return _preferencesFailure('restore', st);
    }
  }

  WalletPreferences _fromRecord(WalletMetadataRecord record) {
    if (validateRecord(record) is! WalletMetadataRecordValid) {
      throw const FormatException('Invalid wallet preference record');
    }
    return WalletPreferences(
      walletRef: record.payload['walletRef']! as String,
      label: record.payload['label'] as String?,
      hideOnHome: record.payload['hideOnHome'] as bool?,
      autoSweepEnabled: record.payload['autoSweepEnabled'] as bool?,
    );
  }

  WalletMetadataRecord _toRecord(WalletPreferences preferences) {
    return WalletMetadataRecord(
      type: type,
      version: version,
      scope: {'kind': 'wallet', 'walletRef': preferences.walletRef},
      recordId: 'preferences',
      payload: {
        'walletRef': preferences.walletRef,
        'label': ?preferences.label,
        'hideOnHome': ?preferences.hideOnHome,
        'autoSweepEnabled': ?preferences.autoSweepEnabled,
      },
    );
  }
}

Result<T, WalletMetadataBackupFailure> _preferencesFailure<T>(
  String operation,
  StackTrace stack,
) {
  // Wallet ids and preference values are private metadata.
  log.severe(
    message: 'Failed to $operation wallet.preferences metadata records',
    error: StateError('wallet.preferences $operation failed'),
    trace: stack,
  );
  return const Err(
    WalletMetadataBackupContributorFailure(
      WalletPreferencesMetadataContributor.type,
    ),
  );
}

bool _samePreferences(WalletPreferences left, WalletPreferences right) {
  return left.walletRef == right.walletRef &&
      left.label == right.label &&
      left.hideOnHome == right.hideOnHome &&
      left.autoSweepEnabled == right.autoSweepEnabled;
}

bool _sameRecordProjection(
  List<WalletMetadataRecord> left,
  List<WalletMetadataRecord> right, {
  required bool hasConflicts,
}) {
  if (hasConflicts) return false;
  final leftByIdentity = {for (final record in left) record.identity: record};
  for (final record in right) {
    final other = leftByIdentity[record.identity];
    if (other == null || !_samePayload(other.payload, record.payload)) {
      return false;
    }
  }
  return true;
}

bool _samePayload(Map<String, Object?> left, Map<String, Object?> right) {
  if (left.length != right.length) return false;
  return left.entries.every((entry) => right[entry.key] == entry.value);
}
