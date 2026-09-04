import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/buy/domain/accelerate_buy_order_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/buy/domain/cancel_abandoned_buy_payjoin_usecase.dart';
import 'package:bb_mobile/features/buy/domain/label_completed_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/load_buy_context_usecase.dart';
import 'package:bb_mobile/features/transactions/transactions_facade.dart';
import 'package:bb_mobile/features/buy/domain/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/create_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/get_buy_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/buy/domain/refresh_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:get_it/get_it.dart';

class BuyLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<CreateBuyOrderUsecase>(
      () => CreateBuyOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
        payjoinReceiver: locator<PayjoinReceiver>(),
        payjoinPolicy: locator<PayjoinPolicyAccess>(),
      ),
    );
    locator.registerFactory<ConfirmBuyOrderUsecase>(
      () => ConfirmBuyOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
        labelsFacade: locator<LabelsFacade>(),
      ),
    );
    locator.registerFactory<RefreshBuyOrderUsecase>(
      () => RefreshBuyOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<AccelerateBuyOrderUsecase>(
      () => AccelerateBuyOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<CancelAbandonedBuyPayjoinUsecase>(
      () => CancelAbandonedBuyPayjoinUsecase(
        locator<PayjoinSessions>(),
        locator<PayjoinReceiver>(),
      ),
    );
    locator.registerFactory<GetBuyPayjoinEnabledUsecase>(
      () => GetBuyPayjoinEnabledUsecase(locator<PayjoinPolicyAccess>()),
    );
    locator.registerFactory<LabelCompletedBuyOrderUsecase>(
      () => LabelCompletedBuyOrderUsecase(
        transactionsFacade: locator<TransactionsFacade>(),
      ),
    );
    locator.registerFactory<LoadBuyContextUsecase>(
      () => LoadBuyContextUsecase(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        getReceiveAddressUsecase: locator<GetReceiveAddressUsecase>(),
        getNetworkFeesUsecase: locator<GetNetworkFeesUsecase>(),
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
      ),
    );
    registerBlocs(locator);
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<BuyBloc>(
      () => BuyBloc(
        loadBuyContextUsecase: locator<LoadBuyContextUsecase>(),
        confirmBuyOrderUsecase: locator<ConfirmBuyOrderUsecase>(),
        createBuyOrderUsecase: locator<CreateBuyOrderUsecase>(),
        refreshBuyOrderUsecase: locator<RefreshBuyOrderUsecase>(),
        accelerateBuyOrderUsecase: locator<AccelerateBuyOrderUsecase>(),
        cancelAbandonedBuyPayjoinUsecase:
            locator<CancelAbandonedBuyPayjoinUsecase>(),
        getBuyPayjoinEnabledUsecase: locator<GetBuyPayjoinEnabledUsecase>(),
        labelCompletedBuyOrderUsecase: locator<LabelCompletedBuyOrderUsecase>(),
      ),
    );
  }
}
