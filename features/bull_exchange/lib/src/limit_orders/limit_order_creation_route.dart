import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../exchange_payout_wallets.dart';
import '../exchange_purchase_routes.dart';
import 'domain/limit_listed_wallets.dart';
import 'domain/usecases/create_limit_order_usecase.dart';
import 'domain/usecases/get_limit_order_rate_usecase.dart';
import 'domain/usecases/get_limit_receive_address_usecase.dart';
import 'domain/usecases/get_recent_limit_orders_usecase.dart';
import 'domain/usecases/load_limit_order_context_usecase.dart';
import 'domain/usecases/validate_lightning_address_usecase.dart';
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
      // Per flow: the app wallets its latest context load listed.
      final listed = LimitListedWallets();
      return LimitFlowBloc(
        session: exchange.currentSession,
        accessChanges: exchange.watchAccess(),
        loadContext: LoadLimitOrderContextUsecase(exchange, payouts, listed),
        getRate: GetLimitOrderRateUsecase(exchange),
        getReceiveAddress: GetLimitReceiveAddressUsecase(payouts, listed),
        validateLightningAddress: const ValidateLightningAddressUsecase(),
        createOrder: CreateLimitOrderUsecase(exchange),
        getRecentOrders: GetRecentLimitOrdersUsecase(exchange),
      );
    },
    child: LimitFlowShell(payoutField: host.payoutField),
  ),
);
