import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
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
  Future<Result<Null, WalletPreferencesFailure>> applyRecovered(
    List<WalletPreferences> preferences,
  ) async {
    try {
      final byWalletRef = <String, WalletPreferences>{};
      for (final preference in preferences) {
        if (!preference.hasRepresentedValue ||
            byWalletRef.containsKey(preference.walletRef)) {
          throw const FormatException(
            'Recovered wallet preferences are invalid',
          );
        }
        byWalletRef[preference.walletRef] = preference;
      }
      final current = {
        for (final metadata in await _metadata.fetchAll())
          metadata.id: metadata,
      };
      final updated = <WalletMetadataModel>[];
      for (final preference in preferences) {
        final metadata = current[preference.walletRef];
        if (metadata == null) {
          throw const FormatException('Recovered wallet is missing');
        }
        updated.add(
          metadata.copyWith(
            label: preference.label,
            hideOnHome: preference.hideOnHome,
            autoSweepEnabled: preference.autoSweepEnabled,
          ),
        );
      }
      await _metadata.storeAll(updated);
      return const Ok(null);
    } on ArgumentError catch (_, st) {
      return _preferencesStorageFailure('restore', st);
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
