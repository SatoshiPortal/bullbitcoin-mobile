import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_new_receive_address_use_case.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/buy/domain/accelerate_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/create_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/refresh_buy_order_usecase.dart';
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
        getNewReceiveAddressUsecase: locator<GetNewReceiveAddressUsecase>(),
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        confirmBuyOrderUsecase: locator<ConfirmBuyOrderUsecase>(),
        createBuyOrderUsecase: locator<CreateBuyOrderUsecase>(),
        getNetworkFeesUsecase: locator<GetNetworkFeesUsecase>(),
        refreshBuyOrderUsecase: locator<RefreshBuyOrderUsecase>(),
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
        accelerateBuyOrderUsecase: locator<AccelerateBuyOrderUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
      ),
    );
  }
}
