import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_preferences_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_behavior_rule.dart';
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
    } on ArgumentError catch (_, st) {
      return _preferencesStorageFailure('read', st);
    } on Exception catch (_, st) {
      return _preferencesStorageFailure('read', st);
    }
  }

  @override
  @useResult
  Future<Result<WalletPreferences, WalletPreferencesFailure>> fetch(
    String walletRef,
  ) async {
    try {
      final metadata = await _metadata.fetch(walletRef);
      return metadata == null
          ? const Err(WalletPreferencesNotFoundFailure())
          : Ok(_fromMetadata(metadata));
    } on Exception catch (_, st) {
      return _preferencesStorageFailure('read', st);
    }
  }

  @override
  @useResult
  Future<Result<WalletPreferences, WalletPreferencesFailure>>
  applyBehaviorDefaults({
    required String walletRef,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) => _writeBehavior(
    walletRef: walletRef,
    requestedHideOnHome: hideOnHome,
    requestedAutoSweepEnabled: autoSweepEnabled,
    defaultsOnly: true,
  );

  @override
  @useResult
  Future<Result<WalletPreferences, WalletPreferencesFailure>> updateBehavior({
    required String walletRef,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) => _writeBehavior(
    walletRef: walletRef,
    requestedHideOnHome: hideOnHome,
    requestedAutoSweepEnabled: autoSweepEnabled,
    defaultsOnly: false,
  );

  Future<Result<WalletPreferences, WalletPreferencesFailure>> _writeBehavior({
    required String walletRef,
    required bool? requestedHideOnHome,
    required bool? requestedAutoSweepEnabled,
    required bool defaultsOnly,
  }) async {
    try {
      final metadata = await _metadata.fetch(walletRef);
      if (metadata == null) {
        return const Err(WalletPreferencesNotFoundFailure());
      }
      final hideOnHome = defaultsOnly
          ? metadata.hideOnHome ?? requestedHideOnHome
          : requestedHideOnHome ?? metadata.hideOnHome;
      final autoSweep = defaultsOnly
          ? metadata.autoSweepEnabled ?? requestedAutoSweepEnabled
          : requestedAutoSweepEnabled ?? metadata.autoSweepEnabled;
      final resolved = resolveWalletBehaviorChange(
        hideOnHome: hideOnHome ?? false,
        autoSweepEnabled: autoSweep ?? false,
      );
      final updated = metadata.copyWith(
        hideOnHome: hideOnHome == null ? null : resolved.hideOnHome,
        autoSweepEnabled: autoSweep == null ? null : resolved.autoSweepEnabled,
      );
      await _metadata.store(updated);
      return Ok(_fromMetadata(updated));
    } on Exception catch (_, st) {
      return _preferencesStorageFailure('write', st);
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
    } on ArgumentError catch (_, st) {
      return _preferencesStorageFailure('restore', st);
    } on Exception catch (_, st) {
      return _preferencesStorageFailure('restore', st);
    }
  }
}

WalletPreferences _fromMetadata(WalletMetadataModel metadata) =>
    WalletPreferences(
      walletRef: metadata.id,
      label: metadata.label,
      hideOnHome: metadata.hideOnHome,
      autoSweepEnabled: metadata.autoSweepEnabled,
    );

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
