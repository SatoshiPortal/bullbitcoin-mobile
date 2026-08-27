import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_default_bitcoin_wallet_fingerprints_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_preferences_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/get_paid_settings_failure.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/get_paid_wallet_behavior.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

final class GetGetPaidWalletBehaviorsUsecase {
  final GetDefaultBitcoinWalletFingerprintsUsecase _getFingerprints;
  final GetWalletPreferencesUsecase _getPreferences;
  final KeychainManifestFacade _manifest;

  const GetGetPaidWalletBehaviorsUsecase(
    this._getFingerprints,
    this._getPreferences,
    this._manifest,
  );

  @useResult
  Future<Result<List<GetPaidWalletBehavior>, GetPaidSettingsFailure>> execute({
    GetPaidWalletProduct? only,
  }) async {
    final List<String> fingerprints;
    try {
      fingerprints = await _getFingerprints.execute();
    } on Exception {
      return const Err(GetPaidSettingsUnavailableFailure());
    }
    if (fingerprints.isEmpty) return const Ok([]);
    if (fingerprints.length != 1) {
      return const Err(GetPaidSettingsUnavailableFailure());
    }
    final parent = Fingerprint.tryParse(fingerprints.single);
    if (parent == null) {
      return const Err(GetPaidSettingsUnavailableFailure());
    }

    final preferencesResult = await _getPreferences.execute();
    final Map<String, WalletPreferences> preferences;
    switch (preferencesResult) {
      case Ok(:final value):
        preferences = {for (final item in value) item.walletRef: item};
      case Err():
        return const Err(GetPaidSettingsUnavailableFailure());
    }

    final products = only == null ? GetPaidWalletProduct.values : [only];
    final behaviors = <GetPaidWalletBehavior>[];
    for (final product in products) {
      final ids = await _manifest.reservationWalletIds(
        parentFingerprint: parent,
        reservationId: product.reservationId,
      );
      switch (ids) {
        case Err():
          return const Err(GetPaidSettingsUnavailableFailure());
        case Ok(value: []):
          continue;
        case Ok(value: [final walletId]):
          final preference = preferences[walletId];
          if (preference == null) continue;
          behaviors.add(
            GetPaidWalletBehavior(
              product: product,
              walletId: walletId,
              hideOnHome: preference.hideOnHome ?? false,
              autoSweepEnabled: preference.autoSweepEnabled ?? false,
            ),
          );
        case Ok():
          return const Err(GetPaidSettingsUnavailableFailure());
      }
    }
    return Ok(List.unmodifiable(behaviors));
  }
}
