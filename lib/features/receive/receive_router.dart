import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/app_router.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/presentation/screens/receive_amount_screen.dart';
import 'package:bb_mobile/features/receive/presentation/screens/receive_invoice_screen.dart';
import 'package:bb_mobile/features/receive/presentation/screens/receive_success_screen.dart';
import 'package:bb_mobile/features/receive/presentation/widgets/receive_network_tabs.dart';
import 'package:bb_mobile/features/receive/presentation/widgets/receive_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ReceiveSubroute {
  invoice('invoice'),
  amount('amount'),
  success('success');

  final String path;

  const ReceiveSubroute(this.path);
}

class ReceiveRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>();

  static final route = ShellRoute(
    navigatorKey: rootNavigatorKey,
    builder: (context, state, child) => BlocProvider<ReceiveBloc>(
      create: (_) => locator<ReceiveBloc>(),
      child: ReceiveScaffold(body: child),
    ),
    routes: [
      ShellRoute(
        navigatorKey: ReceiveRouter.shellNavigatorKey,
        builder: (context, state, child) =>
            BlocListener<ReceiveBloc, ReceiveState>(
          listenWhen: (previous, current) =>
              previous.hasReceived != true && current.hasReceived == true,
          listener: (context, blocState) {
            // Show the success screen when the user has received funds
            context.go(
              '${state.matchedLocation}/${ReceiveSubroute.success.path}',
            );
          },
          child: ReceiveNetworkTabs(
            child: child,
          ),
        ),
        routes: [
          GoRoute(
            name: AppRoute.receiveBitcoin.name,
            path: AppRoute.receiveBitcoin.path,
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) {
              // Entry route, go to bitcoin receive state if not already there
              final bloc = context.read<ReceiveBloc>();
              if (bloc.state is! ReceiveBitcoin) {
                bloc.add(const ReceiveBitcoinStarted());
              }
              return const ReceiveInvoiceScreen();
            },
            routes: [
              GoRoute(
                path: ReceiveSubroute.invoice.path,
                builder: (context, state) => const ReceiveInvoiceScreen(),
              ),
              GoRoute(
                path: ReceiveSubroute.amount.path,
                builder: (context, state) => const ReceiveAmountScreen(),
              ),
              GoRoute(
                path: ReceiveSubroute.success.path,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const ReceiveSuccessScreen(),
              ),
            ],
          ),
          GoRoute(
            name: AppRoute.receiveLightning.name,
            path: AppRoute.receiveLightning.path,
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) {
              // Entry route, go to lightning receive state if not already there
              final bloc = context.read<ReceiveBloc>();
              if (bloc.state is! ReceiveLightning) {
                bloc.add(const ReceiveLightningStarted());
              }
              return const ReceiveAmountScreen();
            },
            routes: [
              GoRoute(
                path: ReceiveSubroute.amount.path,
                builder: (context, state) => const ReceiveInvoiceScreen(),
              ),
              GoRoute(
                path: ReceiveSubroute.amount.path,
                builder: (context, state) => const ReceiveAmountScreen(),
              ),
              GoRoute(
                path: ReceiveSubroute.success.path,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const ReceiveSuccessScreen(),
              ),
            ],
          ),
          GoRoute(
            name: AppRoute.receiveLiquid.name,
            path: AppRoute.receiveLiquid.path,
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) {
              // Entry route, go to liquid receive state if not already there
              final bloc = context.read<ReceiveBloc>();
              if (bloc.state is! ReceiveLiquid) {
                bloc.add(const ReceiveLiquidStarted());
              }
              return const ReceiveInvoiceScreen();
            },
            routes: [
              GoRoute(
                path: ReceiveSubroute.amount.path,
                builder: (context, state) => const ReceiveInvoiceScreen(),
              ),
              GoRoute(
                path: ReceiveSubroute.amount.path,
                builder: (context, state) => const ReceiveAmountScreen(),
              ),
              GoRoute(
                path: ReceiveSubroute.success.path,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const ReceiveSuccessScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
