import 'package:bull_exchange/src/buy/domain/read_buy_payment_animations_usecase.dart';
import 'package:bull_exchange/src/buy/presentation/buy_accelerate_bloc.dart';
import 'package:bull_exchange/src/buy/presentation/buy_flow_bloc.dart';
import 'package:bull_exchange/src/buy/ui/buy_accelerate_shell.dart';
import 'package:bull_exchange/src/buy/ui/buy_flow_shell.dart';
import 'package:bull_exchange/src/buy/ui/buy_router.dart';
import 'package:bull_exchange/src/exchange_payout_wallets.dart';
import 'package:bull_exchange/src/exchange_purchase_routes.dart';
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
        final services = (
          payouts: ExchangePayoutWallets(host.inventory(), host.native()),
          payjoinSessions: host.payjoinSessions(),
          payjoinReceiver: host.payjoinReceiver(),
          payjoinPolicy: host.payjoinPolicy(),
          pollWallet: host.pollWallet,
          labelOrders: host.labelOrders,
          validateBitcoinAddress: host.validateBitcoinAddress,
        );
        return BuyFlowBloc(
          calls: (session) => buyFlowCallsOf(exchange, session, services),
          session: exchange.currentSession,
          accessChanges: exchange.watchAccess(),
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
          final fees = host.fees();
          return AccelerateFlowBloc(
            calls: (session) => accelerateFlowCallsOf(exchange, session, fees),
            session: exchange.currentSession,
            orderId: orderId,
            accessChanges: exchange.watchAccess(),
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
