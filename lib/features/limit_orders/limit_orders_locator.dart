import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/create_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/get_limit_order_rate_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/load_limit_order_creation_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/resolve_wallet_address_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/validate_lightning_address_usecase.dart';
import 'package:bb_mobile/features/limit_orders/public/limit_orders_facade.dart';
import 'package:get_it/get_it.dart';

final class LimitOrdersLocator {
  static void setup(GetIt locator) {
    ExchangeLimitOrders orders() => locator<Exchange>().limitOrders;

    locator.registerFactory<GetLimitOrderRateUsecase>(
      () => GetLimitOrderRateUsecase(orders()),
    );
    locator.registerFactory<CreateLimitOrderUsecase>(
      () => CreateLimitOrderUsecase(orders()),
    );
    locator.registerFactory<LoadLimitOrderCreationUsecase>(
      () => LoadLimitOrderCreationUsecase(
        locator<GetExchangeUserSummaryUsecase>(),
        locator<Exchange>(),
        locator<GetWalletsUsecase>(),
        orders(),
      ),
    );
    locator.registerFactory<ResolveWalletAddressUsecase>(
      () => ResolveWalletAddressUsecase(locator<GetReceiveAddressUsecase>()),
    );
    locator.registerFactory<ValidateLightningAddressUsecase>(
      () => ValidateLightningAddressUsecase(),
    );

    locator.registerLazySingleton<LimitOrdersFacade>(
      () => LimitOrdersFacade(
        locator<LoadLimitOrderCreationUsecase>(),
        locator<GetLimitOrderRateUsecase>(),
        locator<CreateLimitOrderUsecase>(),
        locator<ResolveWalletAddressUsecase>(),
        locator<ValidateLightningAddressUsecase>(),
      ),
    );
  }
}
