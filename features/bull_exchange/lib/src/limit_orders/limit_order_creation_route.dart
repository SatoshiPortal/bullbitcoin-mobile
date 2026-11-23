import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../exchange_payout_wallets.dart';
import '../exchange_purchase_routes.dart';
import 'domain/usecases/create_limit_order_usecase.dart';
import 'domain/usecases/get_limit_order_rate_usecase.dart';
import 'domain/usecases/load_limit_order_creation_usecase.dart';
import 'domain/usecases/resolve_wallet_address_usecase.dart';
import 'domain/usecases/validate_lightning_address_usecase.dart';
import 'limit_orders_navigation.dart';
import 'presentation/create_limit_order_cubit.dart';
import 'ui/screens/create_limit_order_screen.dart';

GoRoute limitOrderCreationRoute(ExchangePurchaseHost host) => GoRoute(
  name: LimitOrdersNavigation.createName,
  path: LimitOrdersNavigation.createPath,
  builder: (_, _) => BlocProvider(
    create: (_) {
      final exchange = host.exchange();
      final orders = exchange.limitOrders;
      final payouts = ExchangePayoutWallets(host.inventory(), host.native());
      return CreateLimitOrderCubit(
        LoadLimitOrderCreationUsecase(
          exchange,
          host.preferences(),
          payouts,
          orders,
        ),
        GetLimitOrderRateUsecase(orders),
        CreateLimitOrderUsecase(orders),
        ResolveWalletAddressUsecase(payouts),
        ValidateLightningAddressUsecase(),
      )..load();
    },
    child: CreateLimitOrderScreen(payoutField: host.payoutField),
  ),
);
