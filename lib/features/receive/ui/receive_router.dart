import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_amount_screen.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_details_screen.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_payjoin_in_progress_screen.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_payment_in_progress_screen.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_payment_received_screen.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_qr_screen.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_scaffold.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ReceiveRoute {
  receiveBitcoin('/receive-bitcoin'),
  receiveLightning('/receive-lightning'),
  receiveLiquid('/receive-liquid'),
  amount('amount'),
  qr('qr'),
  payjoinInProgress('payjoin-in-progress'),
  paymentInProgress('payment-in-progress'),
  paymentReceived('payment-received'),
  details('details');

  final String path;

  const ReceiveRoute(this.path);
}

class ReceiveRouter {
  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>();

  static String getReceiveFlow(String location) {
    if (location.contains('/receive-bitcoin')) return 'bitcoin';
    if (location.contains('/receive-lightning')) return 'lightning';
    if (location.contains('/receive-liquid')) return 'liquid';
    return 'unknown';
  }

  static final route = ShellRoute(
    navigatorKey: _shellNavigatorKey,
    builder: (context, state, child) {
      // Pass a preselected wallet to the receive bloc if one is set in the URI
      //  of the incoming route
      final wallet = state.uri.queryParameters['wallet'] as Wallet?;

      final location = GoRouterState.of(context).matchedLocation;
      final flow = getReceiveFlow(location);

      // Make sure the ReceiveScaffold with the network selection is not rebuild when switching networks,
      // so keep it outside of the BlocProvider.
      // The bloc is recreated when the flow changes (bitcoin, lightning, liquid), but shouldn't be recreated
      // when navigating in the same flow, that's where the KeyedSubtree comes in.
      return ReceiveScaffold(
        child: KeyedSubtree(
          key: ValueKey(flow),
          child: BlocProvider<ReceiveBloc>(
            create: (_) {
              final bloc = locator<ReceiveBloc>(param1: wallet);
              if (flow == 'bitcoin') {
                bloc.add(const ReceiveBitcoinStarted());
              } else if (flow == 'lightning') {
                bloc.add(const ReceiveLightningStarted());
              } else if (flow == 'liquid') {
                bloc.add(const ReceiveLiquidStarted());
              }
              return bloc;
            },
            child: MultiBlocListener(
              listeners: [
                BlocListener<ReceiveBloc, ReceiveState>(
                  listenWhen: (previous, current) =>
                      // makes sure it doesn't go from payment received to payment in progress again
                      previous.isPaymentReceived != true &&
                      previous.isPaymentInProgress != true &&
                      current.isPaymentInProgress == true,
                  listener: (context, state) {
                    final bloc = context.read<ReceiveBloc>();
                    final matched = GoRouterState.of(context).matchedLocation;

                    // For a Payjoin or Lightning receive, show the payment in progress screen
                    //  when the payjoin is requested or swap is claimable.
                    // Since the payment in progress route is outside of the ShellRoute,
                    // it uses the root navigator and so doesn't have the ReceiveBloc
                    //  in the context. We need to pass it as an extra parameter.
                    if (state is BitcoinReceiveState &&
                        state.payjoin?.status == PayjoinStatus.requested) {
                      context.go(
                        '$matched/${ReceiveRoute.payjoinInProgress.path}',
                        extra: bloc,
                      );
                    } else if (state is LightningReceiveState) {
                      context.go(
                        '$matched/${ReceiveRoute.paymentInProgress.path}',
                        extra: bloc,
                      );
                    }
                  },
                ),
                BlocListener<ReceiveBloc, ReceiveState>(
                  listenWhen: (previous, current) =>
                      previous.isPaymentReceived != true &&
                      current.isPaymentReceived == true,
                  listener: (context, state) {
                    final bloc = context.read<ReceiveBloc>();
                    final matched = GoRouterState.of(context).matchedLocation;

                    final path = switch (state) {
                      LightningReceiveState _ =>
                        '$matched/${ReceiveRoute.paymentReceived.path}',
                      _ => '$matched/${ReceiveRoute.details.path}',
                    };

                    context.go(path, extra: bloc);
                  },
                ),
              ],
              child: child,
            ),
          ),
        ),
      );
    },
    routes: [
      // Bitcoin Receive
      GoRoute(
        name: ReceiveRoute.receiveBitcoin.name,
        path: ReceiveRoute.receiveBitcoin.path,
        pageBuilder: (context, state) {
          return const NoTransitionPage(child: ReceiveQrPage());
        },
        routes: [
          GoRoute(
            path: ReceiveRoute.amount.path,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReceiveAmountScreen()),
          ),
          GoRoute(
            path: ReceiveRoute.payjoinInProgress.path,
            parentNavigatorKey: AppRouter.rootNavigatorKey,
            builder: (context, state) {
              final bloc = state.extra! as ReceiveBloc;

              return BlocProvider.value(
                value: bloc,
                child: const ReceivePayjoinInProgressScreen(),
              );
            },
            routes: [
              GoRoute(
                path: ReceiveRoute.details.path,
                parentNavigatorKey: AppRouter.rootNavigatorKey,
                builder: (context, state) {
                  final bloc = state.extra! as ReceiveBloc;

                  return BlocProvider.value(
                    value: bloc,
                    child: const ReceiveDetailsScreen(),
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: ReceiveRoute.details.path,
            parentNavigatorKey: AppRouter.rootNavigatorKey,
            builder: (context, state) {
              final bloc = state.extra! as ReceiveBloc;

              return BlocProvider.value(
                value: bloc,
                child: const ReceiveDetailsScreen(),
              );
            },
          ),
        ],
      ),
      // Lightning receive
      GoRoute(
        name: ReceiveRoute.receiveLightning.name,
        path: ReceiveRoute.receiveLightning.path,
        pageBuilder: (context, state) {
          return NoTransitionPage(
            child: ReceiveAmountScreen(
              onContinueNavigation: () => context.push(
                '${state.matchedLocation}/${ReceiveRoute.qr.path}',
              ),
            ),
          );
        },
        routes: [
          GoRoute(
            path: ReceiveRoute.qr.path,
            pageBuilder: (context, state) {
              return const NoTransitionPage(
                child: ReceiveQrPage(),
              );
            },
          ),
          GoRoute(
            path: ReceiveRoute.amount.path,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReceiveAmountScreen()),
          ),
          GoRoute(
            path: ReceiveRoute.paymentInProgress.path,
            parentNavigatorKey: AppRouter.rootNavigatorKey,
            builder: (context, state) {
              final bloc = state.extra! as ReceiveBloc;

              return BlocProvider.value(
                value: bloc,
                child: const ReceivePaymentInProgressScreen(),
              );
            },
            routes: [
              GoRoute(
                path: ReceiveRoute.paymentReceived.path,
                parentNavigatorKey: AppRouter.rootNavigatorKey,
                builder: (context, state) {
                  final bloc = state.extra! as ReceiveBloc;

                  return BlocProvider.value(
                    value: bloc,
                    child: const ReceivePaymentReceivedScreen(),
                  );
                },
                routes: [
                  GoRoute(
                    path: ReceiveRoute.details.path,
                    parentNavigatorKey: AppRouter.rootNavigatorKey,
                    builder: (context, state) {
                      final bloc = state.extra! as ReceiveBloc;

                      return BlocProvider.value(
                        value: bloc,
                        child: const ReceiveDetailsScreen(),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Liquid receive
      GoRoute(
        name: ReceiveRoute.receiveLiquid.name,
        path: ReceiveRoute.receiveLiquid.path,
        pageBuilder: (context, state) {
          return const NoTransitionPage(
            child: ReceiveQrPage(),
          );
        },
        routes: [
          GoRoute(
            path: ReceiveRoute.amount.path,
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ReceiveAmountScreen()),
          ),
          GoRoute(
            path: ReceiveRoute.details.path,
            parentNavigatorKey: AppRouter.rootNavigatorKey,
            builder: (context, state) {
              final bloc = state.extra! as ReceiveBloc;

              return BlocProvider.value(
                value: bloc,
                child: const ReceiveDetailsScreen(),
              );
            },
          ),
        ],
      ),
    ],
  );
}
