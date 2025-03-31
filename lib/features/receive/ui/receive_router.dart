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

  static final route = ShellRoute(
    navigatorKey: _shellNavigatorKey,
    builder: (context, state, child) {
      return ReceiveScaffold(child: child);
    },
    routes: [
      // Bitcoin Receive
      ShellRoute(
        builder: (context, state, child) {
          // Pass a preselected wallet to the receive bloc if one is set in the URI
          //  of the incoming route
          final wallet = state.uri.queryParameters['wallet'] as Wallet?;
          return BlocProvider<ReceiveBloc>(
            create: (_) => locator<ReceiveBloc>(param1: wallet)
              ..add(const ReceiveBitcoinStarted()),
            child: MultiBlocListener(
              listeners: [
                BlocListener<ReceiveBloc, ReceiveState>(
                  listenWhen: (previous, current) =>
                      // makes sure it doesn't go from payment received to payment in progress again
                      previous.isPaymentReceived != true &&
                      previous.isPaymentInProgress != true &&
                      current.isPaymentInProgress == true,
                  listener: (context, receiveState) {
                    if (receiveState is BitcoinReceiveState &&
                        receiveState.payjoin?.status ==
                            PayjoinStatus.requested) {
                      // For a Payjoin receive, show the payment in progress screen
                      //  when the payment/swap is completed.
                      // Since the payment in progress route is outside of the ShellRoute,
                      // it uses the root navigator and so doesn't have the ReceiveBloc
                      //  in the context. We need to pass it as an extra parameter.
                      context.go(
                        '${state.matchedLocation}/${ReceiveRoute.payjoinInProgress.path}',
                        extra: context.read<ReceiveBloc>(),
                      );
                      return;
                    }
                  },
                ),
                BlocListener<ReceiveBloc, ReceiveState>(
                  listenWhen: (previous, current) =>
                      previous.isPaymentReceived != true &&
                      current.isPaymentReceived == true,
                  listener: (context, receiveState) {
                    // Navigate directly to the details screen for a Bitcoin receive
                    // Since the details route is outside of the ShellRoute,
                    // it uses the root navigator and so doesn't have the ReceiveBloc
                    //  in the context. We need to pass it as an extra parameter.
                    context.go(
                      '${state.matchedLocation}/${ReceiveRoute.details.path}',
                      extra: context.read<ReceiveBloc>(),
                    );
                  },
                ),
              ],
              child: child,
            ),
          );
        },
        routes: [
          // Entry route for a Bitcoin receive
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
        ],
      ),
      // Lightning receive
      ShellRoute(
        builder: (context, state, child) {
          final wallet = state.uri.queryParameters['wallet'] as Wallet?;
          return BlocProvider<ReceiveBloc>(
            create: (_) => locator<ReceiveBloc>(param1: wallet)
              ..add(const ReceiveLightningStarted()),
            child: MultiBlocListener(
              listeners: [
                BlocListener<ReceiveBloc, ReceiveState>(
                  listenWhen: (previous, current) =>
                      // makes sure it doesn't go from payment received to payment in progress again
                      previous.isPaymentReceived != true &&
                      previous.isPaymentInProgress != true &&
                      current.isPaymentInProgress == true,
                  listener: (context, receiveState) {
                    if (receiveState is LightningReceiveState) {
                      // Since the payment in progress route is outside of the ShellRoute,
                      // it uses the root navigator and so doesn't have the ReceiveBloc
                      //  in the context. We need to pass it as an extra parameter.
                      context.go(
                        '${state.matchedLocation}/${ReceiveRoute.paymentInProgress.path}',
                        extra: context.read<ReceiveBloc>(),
                      );
                    }
                  },
                ),
                BlocListener<ReceiveBloc, ReceiveState>(
                  listenWhen: (previous, current) =>
                      previous.isPaymentReceived != true &&
                      current.isPaymentReceived == true,
                  listener: (context, receiveState) {
                    if (receiveState is LightningReceiveState) {
                      // For a Lightning receive, show the payment received screen
                      //  when the payment/swap is completed.
                      // Since the payment received route is outside of the ShellRoute,
                      // it uses the root navigator and so doesn't have the ReceiveBloc
                      //  in the context. We need to pass it as an extra parameter.
                      context.go(
                        '${state.matchedLocation}/${ReceiveRoute.paymentReceived.path}',
                        extra: context.read<ReceiveBloc>(),
                      );
                    }
                  },
                ),
              ],
              child: child,
            ),
          );
        },
        routes: [
          // Entry route for a Lightning receive
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
        ],
      ),
      // Liquid receive
      ShellRoute(
        builder: (context, state, child) {
          // Pass a preselected wallet to the receive bloc if one is set in the URI
          //  of the incoming route
          final wallet = state.uri.queryParameters['wallet'] as Wallet?;
          return BlocProvider<ReceiveBloc>(
            create: (_) => locator<ReceiveBloc>(param1: wallet)
              ..add(const ReceiveLiquidStarted()),
            child: MultiBlocListener(
              listeners: [
                BlocListener<ReceiveBloc, ReceiveState>(
                  listenWhen: (previous, current) =>
                      // makes sure it doesn't go from payment received to payment in progress again
                      previous.isPaymentReceived != true &&
                      previous.isPaymentInProgress != true &&
                      current.isPaymentInProgress == true,
                  listener: (context, receiveState) {
                    // TODO: Navigate to Liquid payment in progress if needed
                  },
                ),
                BlocListener<ReceiveBloc, ReceiveState>(
                  listenWhen: (previous, current) =>
                      previous.isPaymentReceived != true &&
                      current.isPaymentReceived == true,
                  listener: (context, receiveState) {
                    // Go directly to the details screen for a Liquid receive
                    // Since the details route is outside of the ShellRoute,
                    // it uses the root navigator and so doesn't have the ReceiveBloc
                    //  in the context. We need to pass it as an extra parameter.
                    context.go(
                      '${state.matchedLocation}/${ReceiveRoute.details.path}',
                      extra: context.read<ReceiveBloc>(),
                    );
                  },
                ),
              ],
              child: child,
            ),
          );
        },
        routes: [
          // Entry route for a Liquid receive
          GoRoute(
            name: ReceiveRoute.receiveLiquid.name,
            path: ReceiveRoute.receiveLiquid.path,
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
  );
}
