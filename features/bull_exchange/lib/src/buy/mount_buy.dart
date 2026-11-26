import 'package:bull_exchange/src/buy/domain/usecases/accelerate_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/load_accelerate_quote_usecase.dart';
import 'package:bull_exchange/src/buy/domain/buy_listed_wallets.dart';
import 'package:bull_exchange/src/buy/domain/buy_payjoin_uris.dart';
import 'package:bull_exchange/src/buy/domain/read_buy_payment_animations_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/confirm_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/create_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/find_created_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/get_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/get_buy_receive_address_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/load_buy_context_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/refresh_buy_order_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/release_buy_payjoin_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/settle_buy_payout_usecase.dart';
import 'package:bull_exchange/src/buy/domain/usecases/validate_buy_address_usecase.dart';
import 'package:bull_exchange/src/buy/presentation/buy_accelerate_bloc.dart';
import 'package:bull_exchange/src/buy/presentation/buy_flow_bloc.dart';
import 'package:bull_exchange/src/buy/ui/buy_accelerate_shell.dart';
import 'package:bull_exchange/src/buy/ui/buy_flow_shell.dart';
import 'package:bull_exchange/src/buy/ui/buy_router.dart';
import 'package:bull_exchange/src/exchange_payout_wallets.dart';
import 'package:bull_exchange/src/exchange_purchase_routes.dart';
import 'package:bull_exchange/src/orders/domain/usecases/find_created_order_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_market_rate_usecase.dart';
import 'package:bull_exchange/src/orders/domain/usecases/get_order_usecase.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart'
    show AmountDisplayPreferencesReader;
import 'package:primitives/primitives.dart' show BitcoinUnit;

/// The user's bitcoin unit as it changes; an unreadable preference keeps
/// the last one.
Stream<BitcoinUnit> buyBitcoinUnits(AmountDisplayPreferencesReader reader) =>
    reader
        .watchDisplayPreferences()
        .map((result) => result.fold((value) => value.bitcoinUnit, (_) => null))
        .where((unit) => unit != null)
        .cast<BitcoinUnit>()
        .distinct();

/// The buy flow's route and the accelerate route, over the host.
List<RouteBase> mountBuy(ExchangePurchaseHost host) => [
  GoRoute(
    name: BuyRoute.buy.name,
    path: BuyRoute.buy.path,
    builder: (context, state) => BlocProvider(
      create: (_) {
        final exchange = host.exchange();
        final payouts = ExchangePayoutWallets(host.inventory(), host.native());
        final payjoinReceiver = host.payjoinReceiver();
        // Per flow: the wallets it listed and the payjoin URIs its creates
        // attached.
        final listed = BuyListedWallets();
        final uris = BuyPayjoinUris();
        final getOrder = GetOrderUsecase(exchange);
        return BuyFlowBloc(
          session: exchange.currentSession,
          accessChanges: exchange.watchAccess(),
          loadContext: LoadBuyContextUsecase(
            exchange,
            payouts,
            host.payjoinPolicy(),
            listed,
          ),
          getMarketRate: GetMarketRateUsecase(exchange),
          getReceiveAddress: GetBuyReceiveAddressUsecase(payouts, listed),
          validateAddress: ValidateBuyAddressUsecase(
            host.validateBitcoinAddress,
          ),
          createOrder: CreateBuyOrderUsecase(exchange, payjoinReceiver, uris),
          findCreatedOrder: FindCreatedBuyOrderUsecase(
            FindCreatedOrderUsecase(exchange),
            uris,
          ),
          refreshOrder: RefreshBuyOrderUsecase(exchange, uris),
          confirmOrder: ConfirmBuyOrderUsecase(exchange, uris),
          getOrder: getOrder,
          getBuyOrder: GetBuyOrderUsecase(getOrder, uris),
          releasePayjoin: ReleaseBuyPayjoinUsecase(
            host.payjoinSessions(),
            payjoinReceiver,
            uris,
          ),
          settlePayout: SettleBuyPayoutUsecase(
            host.labelOrders,
            host.pollWallet,
          ),
        );
      },
      child: BuyFlowShell(
        unit: buyBitcoinUnits(host.displayPreferences()),
        ui: (
          payoutField: host.payoutField,
          bitcoinAsset: host.bitcoinAsset,
          openOrder: host.openOrder,
          showPaymentAnimations: ReadBuyPaymentAnimationsUsecase(
            host.preferences(),
          ).execute,
        ),
      ),
    ),
  ),
  GoRoute(
    name: BuyRoute.buyAccelerate.name,
    path: BuyRoute.buyAccelerate.path,
    builder: (context, state) {
      final orderId = state.pathParameters['orderId'];
      if (orderId == null) return const SizedBox.shrink();
      return BlocProvider(
        create: (_) {
          final exchange = host.exchange();
          final getOrder = GetOrderUsecase(exchange);
          return AccelerateFlowBloc(
            session: exchange.currentSession,
            orderId: orderId,
            accessChanges: exchange.watchAccess(),
            loadQuote: LoadAccelerateQuoteUsecase(
              exchange,
              host.fees(),
              getOrder,
            ),
            accelerateOrder: AccelerateBuyOrderUsecase(exchange),
            getOrder: getOrder,
          );
        },
        child: AccelerateFlowShell(
          unit: buyBitcoinUnits(host.displayPreferences()),
          openOrder: host.openOrder,
        ),
      );
    },
  ),
];
