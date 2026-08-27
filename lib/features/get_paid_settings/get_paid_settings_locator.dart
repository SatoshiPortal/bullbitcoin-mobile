import 'package:bb_mobile/core/wallet/domain/usecases/get_default_bitcoin_wallet_fingerprints_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_preferences_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:get_it/get_it.dart';

final class GetPaidSettingsLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<GetGetPaidWalletBehaviorsUsecase>(
      () => GetGetPaidWalletBehaviorsUsecase(
        locator<GetDefaultBitcoinWalletFingerprintsUsecase>(),
        locator<GetWalletPreferencesUsecase>(),
        locator<KeychainManifestFacade>(),
      ),
    );
    locator.registerFactory<GetPaidSettingsFacade>(
      () => GetPaidSettingsFacade(
        walletBehaviors: ({only}) =>
            locator<GetGetPaidWalletBehaviorsUsecase>().execute(only: only),
        updateWalletBehavior:
            ({required walletId, hideOnHome, autoSweepEnabled}) async =>
                (await locator<UpdateWalletBehaviorUsecase>().execute(
                      walletId: walletId,
                      hideOnHome: hideOnHome,
                      autoSweepEnabled: autoSweepEnabled,
                    ))
                    .map<void>((_) {})
                    .mapErr((_) => const GetPaidSettingsUnavailableFailure()),
      ),
    );
  }
}
