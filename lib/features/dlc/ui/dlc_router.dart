import 'package:bb_mobile/features/dlc/presentation/bloc/connection/dlc_connection_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/contracts/dlc_contracts_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/my_orders/dlc_my_orders_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/orderbook/dlc_orderbook_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/place_order/dlc_place_order_cubit.dart';
import 'package:bb_mobile/features/dlc/ui/dlc_routes.dart';
import 'package:bb_mobile/features/dlc/ui/screens/dlc_connection_screen.dart';
import 'package:bb_mobile/features/dlc/ui/screens/dlc_contract_detail_screen.dart';
import 'package:bb_mobile/features/dlc/ui/screens/dlc_contracts_screen.dart';
import 'package:bb_mobile/features/dlc/ui/screens/dlc_home_screen.dart';
import 'package:bb_mobile/features/dlc/ui/screens/dlc_my_orders_screen.dart';
import 'package:bb_mobile/features/dlc/ui/screens/dlc_orderbook_screen.dart';
import 'package:bb_mobile/features/dlc/ui/screens/dlc_place_order_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

export 'dlc_routes.dart';

class DlcRouter {
  static final route = GoRoute(
    name: DlcRoute.dlcHome.name,
    path: DlcRoute.dlcHome.path,
    builder: (context, state) => MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => locator<DlcConnectionCubit>()..checkConnection(),
        ),
      ],
      child: const DlcHomeScreen(),
    ),
    routes: [
      GoRoute(
        name: DlcRoute.orderbook.name,
        path: DlcRoute.orderbook.path,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<DlcOrderbookCubit>(),
          child: const DlcOrderbookScreen(),
        ),
      ),
      GoRoute(
        name: DlcRoute.myOrders.name,
        path: DlcRoute.myOrders.path,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<DlcMyOrdersCubit>(),
          child: const DlcMyOrdersScreen(),
        ),
      ),
      GoRoute(
        name: DlcRoute.contracts.name,
        path: DlcRoute.contracts.path,
        builder: (context, state) => BlocProvider.value(
          // DlcContractsCubit is a lazy singleton so the same instance is
          // shared with the detail screen, preserving selectedContract state.
          value: locator<DlcContractsCubit>(),
          child: const DlcContractsScreen(),
        ),
      ),
      GoRoute(
        name: DlcRoute.contractDetail.name,
        path: DlcRoute.contractDetail.path,
        builder: (context, state) => BlocProvider.value(
          value: locator<DlcContractsCubit>(),
          child: const DlcContractDetailScreen(),
        ),
      ),
      GoRoute(
        name: DlcRoute.connection.name,
        path: DlcRoute.connection.path,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<DlcConnectionCubit>(),
          child: const DlcConnectionScreen(),
        ),
      ),
      GoRoute(
        name: DlcRoute.placeOrder.name,
        path: DlcRoute.placeOrder.path,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<DlcPlaceOrderCubit>(),
          child: const DlcPlaceOrderScreen(),
        ),
      ),
    ],
  );
}
