import 'package:bb_mobile/features/dlc/presentation/bloc/auth/dlc_wallet_auth_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/connection/dlc_connection_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/contracts/dlc_contracts_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/instruments/dlc_instruments_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/my_orders/dlc_my_orders_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/orderbook/dlc_orderbook_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/place_order/dlc_place_order_cubit.dart';
import 'package:bb_mobile/features/dlc/ui/dlc_routes.dart';
import 'package:bb_mobile/features/dlc/ui/screens/dlc_main_screen.dart';
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
          create: (_) => locator<DlcWalletAuthCubit>(),
        ),
        BlocProvider(
          create: (_) => locator<DlcConnectionCubit>(),
        ),
        // DlcInstrumentsCubit is a lazy singleton — shared across tabs
        BlocProvider.value(
          value: locator<DlcInstrumentsCubit>(),
        ),
        BlocProvider(
          create: (_) => locator<DlcOrderbookCubit>(),
        ),
        BlocProvider(
          create: (_) => locator<DlcMyOrdersCubit>(),
        ),
        BlocProvider(
          create: (_) => locator<DlcPlaceOrderCubit>(),
        ),
        // DlcContractsCubit is a lazy singleton
        BlocProvider.value(
          value: locator<DlcContractsCubit>(),
        ),
      ],
      child: const DlcMainScreen(),
    ),
  );
}
