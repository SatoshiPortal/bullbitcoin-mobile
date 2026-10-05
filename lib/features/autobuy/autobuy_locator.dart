import 'package:bb_mobile/core/exchange/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/get_autobuy_status_usecase.dart';
import 'package:bb_mobile/features/autobuy/domain/usecases/set_autobuy_usecase.dart';
import 'package:bb_mobile/features/autobuy/public/autobuy_facade.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:get_it/get_it.dart';

class AutoBuyLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<SetAutoBuyUsecase>(
      () => SetAutoBuyUsecase(
        locator<GetExchangeUserSummaryUsecase>(),
        locator<GetDefaultWalletsUsecase>(),
        locator<SettingsRepository>(),
        locator<ExchangeUserRepository>(
          instanceName: 'mainnetExchangeUserRepository',
        ),
        locator<ExchangeUserRepository>(
          instanceName: 'testnetExchangeUserRepository',
        ),
      ),
    );
    locator.registerLazySingleton<GetAutoBuyStatusUsecase>(
      () => GetAutoBuyStatusUsecase(locator<GetExchangeUserSummaryUsecase>()),
    );
    locator.registerLazySingleton<AutoBuyFacade>(
      () => AutoBuyFacade(
        locator<SetAutoBuyUsecase>(),
        locator<GetAutoBuyStatusUsecase>(),
        locator<DefaultWalletsFacade>(),
      ),
    );
  }
}
