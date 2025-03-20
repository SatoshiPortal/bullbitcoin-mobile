import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/receive/ui/screens/receive_screen.dart';
import 'package:bb_mobile/receive/ui/zwidgets/receive_amount_segment.dart';
import 'package:bb_mobile/receive/ui/zwidgets/receive_invoice_segment.dart';
import 'package:bb_mobile/receive/ui/zwidgets/receive_success_body.dart';
import 'package:bb_mobile/router.dart';
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
      child: child,
      // child: ReceiveScaffold(body: child),
    ),
    routes: [
      ShellRoute(
        navigatorKey: ReceiveRouter.shellNavigatorKey,
        builder: (context, state, child) =>
            BlocListener<ReceiveBloc, ReceiveState>(
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
          // child: ReceiveSegmentedButtons(
          //   child: child,
          // ),
        ),
        routes: [
          GoRoute(
            name: AppRoute.receiveBitcoin.name,
            path: AppRoute.receiveBitcoin.path,
            parentNavigatorKey: shellNavigatorKey,
            builder: (context, state) {
              // Entry route, go to bitcoin receive state if not already there
              final bloc = context.read<ReceiveBloc>();
              //if (bloc.state.paymentNetwork != ReceivePaymentNetwork.bitcoin) {
              bloc.add(const ReceiveBitcoinStarted());
              //}
              return const ReceiveScreen();
              // return const ReceiveInvoiceSegment();
            },
            routes: [
              GoRoute(
                path: ReceiveSubroute.invoice.path,
                builder: (context, state) => const ReceiveInvoiceSegment(),
              ),
              GoRoute(
                path: ReceiveSubroute.amount.path,
                builder: (context, state) => const ReceiveAmountSegment(),
              ),
              GoRoute(
                path: ReceiveSubroute.success.path,
                parentNavigatorKey: rootNavigatorKey,
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
              //if (bloc.state.paymentNetwork !=
              // ReceivePaymentNetwork.lightning) {
              bloc.add(const ReceiveLightningStarted());
              // }
              return const ReceiveAmountSegment();
            },
            routes: [
              GoRoute(
                path: ReceiveSubroute.amount.path,
                builder: (context, state) => const ReceiveInvoiceSegment(),
              ),
              GoRoute(
                path: ReceiveSubroute.amount.path,
                builder: (context, state) => const ReceiveAmountSegment(),
              ),
              GoRoute(
                path: ReceiveSubroute.success.path,
                parentNavigatorKey: rootNavigatorKey,
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
              //if (bloc.state.paymentNetwork != ReceivePaymentNetwork.liquid) {
              bloc.add(const ReceiveLiquidStarted());
              //}
              return const ReceiveInvoiceSegment();
            },
            routes: [
              GoRoute(
                path: ReceiveSubroute.amount.path,
                builder: (context, state) => const ReceiveInvoiceSegment(),
              ),
              GoRoute(
                path: ReceiveSubroute.amount.path,
                builder: (context, state) => const ReceiveAmountSegment(),
              ),
              GoRoute(
                path: ReceiveSubroute.success.path,
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const ReceiveSuccessBody(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
