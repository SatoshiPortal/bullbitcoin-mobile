import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
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
      // Pass a preselected wallet to the receive bloc if one is set in the URI
      //  of the incoming route
      Wallet? wallet;
      if (state.extra is Wallet) {
        wallet = state.extra! as Wallet;
      }

      // Make sure the ReceiveScaffold with the network selection is not rebuild
      //  when switching networks, so keep it outside of the BlocProvider.
      return ReceiveScaffold(
        wallet: wallet,
        child: BlocProvider<ReceiveBloc>(
          create: (_) => locator<ReceiveBloc>(param1: wallet),
          child: MultiBlocListener(
            listeners: [
              BlocListener<ReceiveBloc, ReceiveState>(
                listenWhen:
                    (previous, current) =>
                        // makes sure it doesn't go from payment received to payment in progress again
                        previous.isPaymentReceived != true &&
                        previous.isPaymentInProgress != true &&
                        current.isPaymentInProgress == true,
                listener: (context, state) {
                  final bloc = context.read<ReceiveBloc>();
                  final matched = GoRouterState.of(context).matchedLocation;
                  final type = state.type;

                  // For a Payjoin or Lightning receive, show the payment in progress screen
                  //  when the payjoin is requested or swap is claimable.
                  // Since the payment in progress route is outside of the ShellRoute,
                  // it uses the root navigator and so doesn't have the ReceiveBloc
                  //  in the context. We need to pass it as an extra parameter.
                  if (type == ReceiveType.bitcoin &&
                      state.payjoin?.status == PayjoinStatus.requested) {
                    context.go(
                      '$matched/${ReceiveRoute.payjoinInProgress.path}',
                      extra: bloc,
                    );
                  } else if (type == ReceiveType.lightning) {
                    context.go(
                      '$matched/${ReceiveRoute.paymentInProgress.path}',
                      extra: bloc,
                    );
                  }
                },
              ),
              BlocListener<ReceiveBloc, ReceiveState>(
                listenWhen:
                    (previous, current) =>
                        previous.isPaymentReceived != true &&
                        current.isPaymentReceived == true,
                listener: (context, state) {
                  final bloc = context.read<ReceiveBloc>();
                  final matched = GoRouterState.of(context).matchedLocation;
                  final type = state.type;

                  final path = switch (type) {
                    ReceiveType.lightning =>
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
      );
    },
    routes: [
      // Bitcoin Receive
      GoRoute(
        name: ReceiveRoute.receiveBitcoin.name,
        path: ReceiveRoute.receiveBitcoin.path,
        pageBuilder: (context, state) {
          // This is the entry route for the bitcoin receive flow when coming from
          // another receive network (lightning or liquid) or from a different flow.
          // So we should start the bitcoin flow here if the state is not already
          //  in the bitcoin flow.
          final bloc = context.read<ReceiveBloc>();
          if (bloc.state.type != ReceiveType.bitcoin) {
            bloc.add(const ReceiveBitcoinStarted());
          }
          Wallet? wallet;
          if (state.extra is Wallet) {
            wallet = state.extra! as Wallet;
          }
          return NoTransitionPage(child: ReceiveQrPage(wallet: wallet));
        },
        routes: [
          GoRoute(
            path: ReceiveRoute.amount.path,
            pageBuilder:
                (context, state) =>
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
          // This is the entry route for the lightning receive flow.
          // We need to check if the state is already in the lightning flow,
          //  otherwise, when coming from another receive network or flow,
          //  we need to start it here.
          final bloc = context.read<ReceiveBloc>();
          if (bloc.state.type != ReceiveType.lightning) {
            bloc.add(const ReceiveLightningStarted());
          }
          return NoTransitionPage(
            child: ReceiveAmountScreen(
              onContinueNavigation:
                  () => context.push(
                    '${state.matchedLocation}/${ReceiveRoute.qr.path}',
                    extra: state.extra,
                  ),
            ),
          );
        },
        routes: [
          GoRoute(
            path: ReceiveRoute.qr.path,
            pageBuilder: (context, state) {
              Wallet? wallet;
              if (state.extra is Wallet) {
                wallet = state.extra! as Wallet;
              }
              return NoTransitionPage(child: ReceiveQrPage(wallet: wallet));
            },
          ),
          GoRoute(
            path: ReceiveRoute.amount.path,
            pageBuilder:
                (context, state) =>
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
          // This is the entry route for the liquid receive flow when coming from
          // another receive network (lightning or bitcoin) or from a different flow.
          // So if the state is already in the liquid flow, we don't have to do
          //  anything, else we need to start it here.
          final bloc = context.read<ReceiveBloc>();
          if (bloc.state.type != ReceiveType.liquid) {
            bloc.add(const ReceiveLiquidStarted());
          }
          Wallet? wallet;
          if (state.extra is Wallet) {
            wallet = state.extra! as Wallet;
          }
          return NoTransitionPage(child: ReceiveQrPage(wallet: wallet));
        },
        routes: [
          GoRoute(
            path: ReceiveRoute.amount.path,
            pageBuilder:
                (context, state) =>
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
