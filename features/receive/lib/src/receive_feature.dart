import 'domain/usecases/get_receive_swap_limits_usecase.dart';

import 'package:receive/receive.dart';

import 'package:receive/src/domain/usecases/poll_receive_wallet_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:address_view/address_view.dart';
import 'package:transactions/transactions.dart';
import 'package:labels/labels.dart';
import 'package:receive/src/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:receive/src/domain/usecases/get_receive_payjoin_policy_usecase.dart';
import 'package:receive/src/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:receive/src/domain/usecases/create_boltz_receive_swap_usecase.dart';
import 'package:receive/src/domain/usecases/get_receive_swap_route_usecase.dart';
import 'package:receive/src/domain/usecases/get_receive_address_at_index_usecase.dart';
import 'package:receive/src/domain/usecases/get_receive_wallets_usecase.dart';
import 'package:receive/src/domain/usecases/prepare_receive_address_usecase.dart';
import 'package:receive/src/domain/usecases/read_receive_payment_animations_usecase.dart';
import 'package:receive/src/domain/usecases/set_receive_payjoin_enabled_usecase.dart';
import 'package:receive/src/domain/usecases/watch_payjoin_usecase.dart';
import 'package:receive/src/domain/usecases/watch_receive_order_swap_usecase.dart';
import 'package:receive/src/domain/usecases/watch_receive_settlement_usecase.dart';
import 'package:receive/src/domain/usecases/watch_receive_payjoin_min_amount_usecase.dart';
import 'package:receive/src/domain/usecases/watch_receive_payjoin_enabled_usecase.dart';
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:swaps/swaps.dart'
    show
        BoltzSwaps,
        GetSwapLimitsAndFeesUsecase,
        SwapRouting,
        SwapWatcher,
        WatchSwapUsecase;
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:secrets/secrets.dart';
import 'package:swaps/order_swaps.dart';

import 'ui/receive_router.dart';

final class ReceiveFeature {
  final ShellRoute route;

  const ReceiveFeature._(this.route);

  static ReceiveFeature mount(
    GetIt locator, {
    required GlobalKey<NavigatorState> rootNavigatorKey,
    required WalletInventory inventory,
    required LoadReceiveWallet loadWallet,
    required ReadReceiveSigner readSigner,
    required PollReceiveWallet poll,
    required Future<void> Function() refreshAfterLightningPayment,
    required ReadOrderSwaps Function() orderSwaps,
    required CreateReceiveOrder createOrder,
    required SetReceivePayjoinEnabled setPayjoinEnabled,
    required void Function(BuildContext) openHome,
    required void Function(BuildContext) openPayjoinSettings,
    required ImageProvider successAnimation,
    required Widget Function(OrderSwapRecord) orderSwapUnderReview,
  }) {
    locator.registerFactory<PollReceiveWalletUsecase>(
      () => PollReceiveWalletUsecase(poll),
    );
    locator.registerFactory<ReceiveWithPayjoinUsecase>(
      () => ReceiveWithPayjoinUsecase(locator<PayjoinReceiver>()),
    );
    locator.registerFactory<BroadcastOriginalTransactionUsecase>(
      () => BroadcastOriginalTransactionUsecase(locator<PayjoinSender>()),
    );
    locator.registerFactory<WatchPayjoinUsecase>(
      () => WatchPayjoinUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<GetReceivePayjoinPolicyUsecase>(
      () => GetReceivePayjoinPolicyUsecase(locator<PayjoinPolicyAccess>()),
    );
    locator.registerFactory<WatchReceivePayjoinEnabledUsecase>(
      () => WatchReceivePayjoinEnabledUsecase(locator<PayjoinPolicyAccess>()),
    );
    locator.registerFactory<GetReceiveSwapRouteUsecase>(
      () => GetReceiveSwapRouteUsecase(locator<SwapRouting>()),
    );
    locator.registerFactory<CreateBoltzReceiveSwapUsecase>(
      () => CreateBoltzReceiveSwapUsecase(
        locator<BoltzSwaps>(),
        locator<SwapWatcher>(),
      ),
    );
    locator.registerFactory<SetReceivePayjoinEnabledUsecase>(
      () => SetReceivePayjoinEnabledUsecase(setPayjoinEnabled),
    );
    locator.registerFactory<WatchReceivePayjoinMinAmountUsecase>(
      () => WatchReceivePayjoinMinAmountUsecase(locator<PayjoinPolicyAccess>()),
    );
    locator.registerFactory<WatchReceiveSettlementUsecase>(
      () => WatchReceiveSettlementUsecase(locator<Transactions>()),
    );
    locator.registerFactory<WatchReceiveOrderSwapUsecase>(
      () => WatchReceiveOrderSwapUsecase(orderSwaps),
    );

    final wallets = GetReceiveWalletsUsecase(
      locator<ActiveEnvironmentReader>(),
      inventory,
      loadWallet,
      readSigner,
    );
    locator.registerFactory<PrepareReceiveAddressUsecase>(
      () => PrepareReceiveAddressUsecase(locator<AddressView>()),
    );
    locator.registerFactory<GetReceiveAddressAtIndexUsecase>(
      () => GetReceiveAddressAtIndexUsecase(locator<AddressView>()),
    );

    locator.registerFactory<GetReceiveSwapLimitsUsecase>(
      () => GetReceiveSwapLimitsUsecase(locator<GetSwapLimitsAndFeesUsecase>()),
    );

    locator.registerLazySingleton<Receive>(
      () => Receive.open(
        addresses: locator<AddressView>(),
        labels: locator<Labels>(),
        preferences: locator<Preferences>(),
        readPrice: Pricer.getIndexPrice,
        readPrices: Pricer.getIndexPrices,
      ),
    );

    // Bloc
    locator.registerFactoryParam<ReceiveBloc, ReceiveWallet?, void>(
      (wallet, _) => ReceiveBloc(
        getReceiveSwapLimitsUsecase: locator<GetReceiveSwapLimitsUsecase>(),
        getReceiveWalletsUsecase: wallets,
        resolveEntry: wallets.resolveEntry,
        refreshAfterLightningPayment: refreshAfterLightningPayment,
        receive: locator<Receive>(),
        prepareReceiveAddressUsecase: locator<PrepareReceiveAddressUsecase>(),
        createReceiveOrderSwapUsecase: createOrder,
        getReceiveSwapRouteUsecase: locator<GetReceiveSwapRouteUsecase>(),
        createBoltzReceiveSwapUsecase: locator<CreateBoltzReceiveSwapUsecase>(),
        watchSwapUsecase: locator<WatchSwapUsecase>(),
        receiveWithPayjoinUsecase: locator<ReceiveWithPayjoinUsecase>(),
        broadcastOriginalTransactionUsecase:
            locator<BroadcastOriginalTransactionUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        transactions: locator<Transactions>(),
        watchReceiveSettlementUsecase: locator<WatchReceiveSettlementUsecase>(),
        watchReceiveOrderSwapUsecase: locator<WatchReceiveOrderSwapUsecase>(),
        watchReceivePayjoinEnabledUsecase:
            locator<WatchReceivePayjoinEnabledUsecase>(),
        watchReceivePayjoinMinAmountUsecase:
            locator<WatchReceivePayjoinMinAmountUsecase>(),
        getReceivePayjoinPolicyUsecase:
            locator<GetReceivePayjoinPolicyUsecase>(),
        setReceivePayjoinEnabledUsecase:
            locator<SetReceivePayjoinEnabledUsecase>(),
        readPaymentAnimationsUsecase: ReadReceivePaymentAnimationsUsecase(
          locator<Preferences>(),
        ),
        wallet: wallet,
      ),
    );
    return ReceiveFeature._(
      ReceiveRouter.mount(
        rootNavigatorKey: rootNavigatorKey,
        createBloc: (wallet) => locator<ReceiveBloc>(param1: wallet),
        poll: locator<PollReceiveWalletUsecase>(),
        openHome: openHome,
        openPayjoinSettings: openPayjoinSettings,
        successAnimation: successAnimation,
        orderSwapUnderReview: orderSwapUnderReview,
      ),
    );
  }
}
