import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../exchange_payout_wallets.dart';
import '../exchange_purchase_routes.dart';
import 'limit_orders_navigation.dart';
import 'presentation/limit_order_flow_bloc.dart';
import 'ui/limit_order_flow_shell.dart';

/// One route: the flow's page is a function of its state
/// ([LimitFlowShell]).
GoRoute limitOrderCreationRoute(ExchangePurchaseHost host) => GoRoute(
  name: LimitOrdersNavigation.createName,
  path: LimitOrdersNavigation.createPath,
  builder: (_, _) => BlocProvider(
    create: (_) {
      final exchange = host.exchange();
      final payouts = ExchangePayoutWallets(host.inventory(), host.native());
      return LimitFlowBloc(
        calls: (session) => limitFlowCallsOf(exchange, session, payouts),
        session: exchange.currentSession,
        accessChanges: exchange.watchAccess(),
      );
    },
    child: LimitFlowShell(payoutField: host.payoutField),
  ),
);
