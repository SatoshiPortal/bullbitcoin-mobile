import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:exchange/exchange.dart';
import 'package:fees/fees.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

import 'buy/domain/accelerate_buy_order_usecase.dart';
import 'buy/domain/cancel_abandoned_buy_payjoin_usecase.dart';
import 'buy/domain/confirm_buy_order_usecase.dart';
import 'buy/domain/create_buy_order_usecase.dart';
import 'buy/domain/get_buy_payjoin_enabled_usecase.dart';
import 'buy/domain/label_completed_buy_order_usecase.dart';
import 'buy/domain/load_buy_context_usecase.dart';
import 'buy/domain/refresh_buy_order_usecase.dart';
import 'buy/domain/sync_buy_receipt_usecase.dart';
import 'buy/domain/validate_buy_destination_usecase.dart';
import 'buy/domain/watch_buy_bitcoin_unit_usecase.dart';
import 'buy/presentation/buy_bloc.dart';
import 'buy/ui/buy_router.dart';
import 'dca/domain/usecases/set_dca_usecase.dart';
import 'dca/domain/usecases/start_dca_usecase.dart';
import 'dca/presentation/dca_bloc.dart';
import 'dca/ui/dca_router.dart';
import 'exchange_payout_field.dart';
import 'exchange_payout_wallets.dart';

typedef ExchangePurchaseHost = ({
  Exchange Function() exchange,
  Preferences Function() preferences,
  AmountDisplayPreferencesReader Function() displayPreferences,
  WalletInventory Function() inventory,
  WalletNativeLifecycle Function() native,
  Fees Function() fees,
  PayjoinSessions Function() payjoinSessions,
  PayjoinReceiver Function() payjoinReceiver,
  PayjoinPolicyAccess Function() payjoinPolicy,
  Future<void> Function(String) pollWallet,
  Future<void> Function(List<Order>) labelOrders,
  Future<String?> Function(String) validateBitcoinAddress,
  ExchangePayoutField payoutField,
  String bitcoinAsset,
  void Function(BuildContext) onClose,
  void Function(BuildContext, String) openOrder,
});

List<RouteBase> mountBuy(ExchangePurchaseHost host) => BuyRouter.routes(
  payoutField: host.payoutField,
  bitcoinAsset: host.bitcoinAsset,
  onClose: host.onClose,
  openOrder: host.openOrder,
  createBloc: () {
    final exchange = host.exchange();
    final preferences = host.preferences();
    return BuyBloc(
      validateDestination: ValidateBuyDestinationUsecase(
        host.validateBitcoinAddress,
      ),
      watchBitcoinUnitUsecase: WatchBuyBitcoinUnitUsecase(
        host.displayPreferences(),
      ),
      syncBuyReceiptUsecase: SyncBuyReceiptUsecase(host.pollWallet),
      loadBuyContextUsecase: LoadBuyContextUsecase(
        exchange: exchange,
        getSettingsUsecase: preferences,
        payouts: ExchangePayoutWallets(host.inventory(), host.native()),
        fees: host.fees(),
        getIndexPrice: Pricer.getIndexPrice,
      ),
      confirmBuyOrderUsecase: ConfirmBuyOrderUsecase(
        exchange: exchange,
        settingsRepository: preferences,
      ),
      createBuyOrderUsecase: CreateBuyOrderUsecase(
        exchange: exchange,
        settingsRepository: preferences,
        payjoinPolicy: host.payjoinPolicy(),
        payjoinReceiver: host.payjoinReceiver(),
      ),
      refreshBuyOrderUsecase: RefreshBuyOrderUsecase(
        exchange: exchange,
        settingsRepository: preferences,
      ),
      accelerateBuyOrderUsecase: AccelerateBuyOrderUsecase(
        exchange: exchange,
        settingsRepository: preferences,
      ),
      cancelAbandonedBuyPayjoinUsecase: CancelAbandonedBuyPayjoinUsecase(
        host.payjoinSessions(),
        host.payjoinReceiver(),
      ),
      getBuyPayjoinEnabledUsecase: GetBuyPayjoinEnabledUsecase(
        host.payjoinPolicy(),
      ),
      labelCompletedBuyOrderUsecase: LabelCompletedBuyOrderUsecase(
        host.labelOrders,
      ),
    );
  },
);

GoRoute mountDca(ExchangePurchaseHost host) => DcaRouter.route(
  payoutField: host.payoutField,
  createBloc: () {
    final exchange = host.exchange();
    final preferences = host.preferences();
    return DcaBloc(
      startDcaUsecase: StartDcaUsecase(
        settingsRepository: preferences,
        exchange: exchange,
      ),
      setDcaUsecase: SetDcaUsecase(
        payouts: ExchangePayoutWallets(host.inventory(), host.native()),
        settingsRepository: preferences,
        exchange: exchange,
      ),
    );
  },
);
