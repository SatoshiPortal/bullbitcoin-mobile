import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_preferences_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_preferences_failure.dart';
import 'package:meta/meta.dart';

final class WalletPreferencesRepositoryImpl
    implements WalletPreferencesRepository {
  final WalletMetadataDatasource _metadata;

  const WalletPreferencesRepositoryImpl(this._metadata);

  @override
  Stream<void> get changes => _metadata.preferenceChanges;

  @override
  @useResult
  Future<Result<List<WalletPreferences>, WalletPreferencesFailure>>
  fetchAll() async {
    try {
      final metadata = await _metadata.fetchAll();
      if (metadata.any((wallet) => wallet.id.isEmpty)) {
        return _preferencesStorageFailure('read', StackTrace.current);
      }
      return Ok(
        List.unmodifiable(
          metadata.map(
            (wallet) => WalletPreferences(
              walletRef: wallet.id,
              label: wallet.label,
              hideOnHome: wallet.hideOnHome,
              autoSweepEnabled: wallet.autoSweepEnabled,
            ),
          ),
        ),
      );
    } on Exception catch (_, st) {
      return _preferencesStorageFailure('read', st);
    }
  }

  @override
  @useResult
  Future<Result<WalletPreferencesRecoveryApplyResult, WalletPreferencesFailure>>
  applyRecovered(List<WalletPreferencesRecoveryUpdate> updates) async {
    try {
      final byWalletRef = <String, WalletPreferencesRecoveryUpdate>{};
      for (final update in updates) {
        if (!update.recovered.hasRepresentedValue ||
            byWalletRef.containsKey(update.recovered.walletRef)) {
          throw const FormatException(
            'Recovered wallet preferences are invalid',
          );
        }
        byWalletRef[update.recovered.walletRef] = update;
      }
      final conflicts = await _metadata.storeRecoveredPreferencesConditionally(
        updates
            .map(
              (update) => WalletMetadataPreferenceRecoveryUpdate(
                walletRef: update.recovered.walletRef,
                expectedLabel: update.expected.label,
                expectedHideOnHome: update.expected.hideOnHome,
                expectedAutoSweepEnabled: update.expected.autoSweepEnabled,
                recoveredLabel: update.recovered.label,
                recoveredHideOnHome: update.recovered.hideOnHome,
                recoveredAutoSweepEnabled: update.recovered.autoSweepEnabled,
              ),
            )
            .toList(growable: false),
      );
      return Ok(
        WalletPreferencesRecoveryApplyResult(
          appliedWalletRefs: byWalletRef.keys.toSet()..removeAll(conflicts),
          conflictedWalletRefs: conflicts,
        ),
      );
    } on Exception catch (_, st) {
      return _preferencesStorageFailure('restore', st);
    }
  }
}

Result<T, WalletPreferencesFailure> _preferencesStorageFailure<T>(
  String operation,
  StackTrace stack,
) {
  // Wallet metadata is private; neither row values nor raw mapper/storage
  // exceptions are attached to logs.
  log.severe(
    message: 'Failed to $operation wallet preferences',
    error: StateError('Wallet preferences $operation failed'),
    trace: stack,
  );
  return const Err(WalletPreferencesStorageFailure());
}
