import 'package:bb_mobile/core/exchange/domain/usecases/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_buy_order_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_order_usercase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/refresh_buy_order_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_use_case.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/locator.dart';

class BuyLocator {
  static void setup() {
    registerBlocs();
  }

  static void registerBlocs() {
    locator.registerFactory<BuyBloc>(
      () => BuyBloc(
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        getReceiveAddressUsecase: locator<GetReceiveAddressUsecase>(),
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        confirmBuyOrderUsecase: locator<ConfirmBuyOrderUsecase>(),
        createBuyOrderUsecase: locator<CreateBuyOrderUsecase>(),
        getOrderUsecase: locator<GetOrderUsecase>(),
        refreshBuyOrderUsecase: locator<RefreshBuyOrderUsecase>(),
      ),
    );
  }
}
