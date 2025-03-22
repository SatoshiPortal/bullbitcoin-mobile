import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/receive/ui/screens/receive_amount_screen.dart';
import 'package:bb_mobile/receive/ui/screens/receive_qr_screen.dart';
import 'package:bb_mobile/receive/ui/zwidgets/receive_success_body.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ReceiveSubroute {
  invoice('qr'),
  amount('amount'),
  success('success');

  final String path;

  const ReceiveSubroute(this.path);
}

class ReceiveRouter {
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>();

  static final route = ShellRoute(
    navigatorKey: shellNavigatorKey,
    builder: (context, state, child) {
      // Pass a preselected wallet to the receive bloc if available
      final wallet = state.extra as Wallet?;
      return BlocProvider<ReceiveBloc>(
        create: (_) => locator<ReceiveBloc>(param1: wallet),
        child: BlocListener<ReceiveBloc, ReceiveState>(
          listenWhen: (previous, current) =>
              previous.hasReceivedFunds != true &&
              current.hasReceivedFunds == true,
          listener: (context, blocState) {
            // Show the success screen when the user has received funds
            context.go(
              '${state.matchedLocation}/${ReceiveSubroute.success.path}',
            );
          },
          child: child,
        ),
      );
    },
    routes: [
      GoRoute(
        name: AppRoute.receiveBitcoin.name,
        path: AppRoute.receiveBitcoin.path,
        parentNavigatorKey: shellNavigatorKey,
        builder: (context, state) {
          // Entry route, start a bitcoin receive if not already there
          final bloc = context.read<ReceiveBloc>();
          if (bloc.state is! BitcoinReceiveState) {
            bloc.add(const ReceiveBitcoinStarted());
          }
          return const ReceiveQrScreen();
        },
        routes: [
          GoRoute(
            path: ReceiveSubroute.amount.path,
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) => const ReceiveAmountScreen(),
          ),
          GoRoute(
            path: ReceiveSubroute.success.path,
            parentNavigatorKey: AppRouter.rootNavigatorKey,
            builder: (context, state) => const ReceiveSuccessBody(),
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
          if (bloc.state is! LightningReceiveState) {
            bloc.add(const ReceiveLightningStarted());
          }
          return const ReceiveAmountScreen();
        },
        routes: [
          GoRoute(
            path: ReceiveSubroute.invoice.path,
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) => const ReceiveQrScreen(),
          ),
          GoRoute(
            path: ReceiveSubroute.amount.path,
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) => const ReceiveAmountScreen(),
          ),
          GoRoute(
            path: ReceiveSubroute.success.path,
            parentNavigatorKey: AppRouter.rootNavigatorKey,
            builder: (context, state) => const ReceiveSuccessBody(),
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
          if (bloc.state is! LiquidReceiveState) {
            bloc.add(const ReceiveLiquidStarted());
          }
          return const ReceiveQrScreen();
        },
        routes: [
          GoRoute(
            path: ReceiveSubroute.amount.path,
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) => const ReceiveAmountScreen(),
          ),
          GoRoute(
            path: ReceiveSubroute.success.path,
            parentNavigatorKey: AppRouter.rootNavigatorKey,
            builder: (context, state) => const ReceiveSuccessBody(),
          ),
        ],
      ),
    ],
  );
}
