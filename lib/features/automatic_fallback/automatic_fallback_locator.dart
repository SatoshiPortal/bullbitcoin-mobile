import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/ensure_automatic_fallback_address_usecase.dart';
import 'package:bb_mobile/features/automatic_fallback/public/automatic_fallback_facade.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:get_it/get_it.dart';

class AutomaticFallbackLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<EnsureAutomaticFallbackAddressUsecase>(
      () => EnsureAutomaticFallbackAddressUsecase(
        locator<GetSettingsUsecase>(),
        locator<WalletRepository>(),
        locator<WalletAddressRepository>(),
        locator<BitcoinWalletRepository>(),
        locator<LabelsFacade>(),
        locator<BullnymFacade>().lookupRecoveryAddress,
        locator<BullnymFacade>().registerRecoveryAddress,
      ),
    );
    locator.registerFactory<AutomaticFallbackFacade>(
      () => AutomaticFallbackFacade.fromUsecase(
        locator<EnsureAutomaticFallbackAddressUsecase>(),
      ),
    );
  }
}
