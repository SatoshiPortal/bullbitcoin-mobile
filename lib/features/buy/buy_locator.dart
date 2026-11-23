import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart'
    show AmountDisplayPreferencesReader, Preferences;
import 'package:bb_mobile/features/buy/domain/watch_buy_bitcoin_unit_usecase.dart';
import 'package:bb_mobile/features/buy/domain/sync_buy_receipt_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:fees/fees.dart';
import 'package:bb_mobile/features/address_view/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/buy/domain/accelerate_buy_order_usecase.dart';
import 'package:labels/labels.dart';
import 'package:bb_mobile/features/buy/domain/cancel_abandoned_buy_payjoin_usecase.dart';
import 'package:bb_mobile/features/buy/domain/label_completed_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/load_buy_context_usecase.dart';
import 'package:transactions/transactions.dart';
import 'package:bb_mobile/features/buy/domain/confirm_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/create_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/domain/get_buy_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/buy/domain/refresh_buy_order_usecase.dart';
import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:get_it/get_it.dart';

class BuyLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<SyncBuyReceiptUsecase>(
      () => SyncBuyReceiptUsecase(locator<WalletFacade>()),
    );
    locator.registerFactory<CreateBuyOrderUsecase>(
      () => CreateBuyOrderUsecase(
        exchange: locator<Exchange>(),
        settingsRepository: locator<Preferences>(),
        payjoinReceiver: locator<PayjoinReceiver>(),
        payjoinPolicy: locator<PayjoinPolicyAccess>(),
      ),
    );
    locator.registerFactory<ConfirmBuyOrderUsecase>(
      () => ConfirmBuyOrderUsecase(
        exchange: locator<Exchange>(),
        settingsRepository: locator<Preferences>(),
        labelsFacade: locator<Labels>(),
      ),
    );
    locator.registerFactory<RefreshBuyOrderUsecase>(
      () => RefreshBuyOrderUsecase(
        exchange: locator<Exchange>(),
        settingsRepository: locator<Preferences>(),
      ),
    );
    locator.registerFactory<AccelerateBuyOrderUsecase>(
      () => AccelerateBuyOrderUsecase(
        exchange: locator<Exchange>(),
        settingsRepository: locator<Preferences>(),
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
        transactionsFacade: locator<Transactions>(),
      ),
    );
    locator.registerFactory<LoadBuyContextUsecase>(
      () => LoadBuyContextUsecase(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        getSettingsUsecase: locator<Preferences>(),
        getWalletsUsecase: locator<GetWalletsUsecase>(),
        getReceiveAddressUsecase: locator<GetReceiveAddressUsecase>(),
        fees: locator<Fees>(),
        getIndexPrice: Pricer.getIndexPrice,
      ),
    );
    registerBlocs(locator);
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<BuyBloc>(
      () => BuyBloc(
        watchBitcoinUnitUsecase: WatchBuyBitcoinUnitUsecase(
          locator<AmountDisplayPreferencesReader>(),
        ),
        syncBuyReceiptUsecase: locator<SyncBuyReceiptUsecase>(),
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
