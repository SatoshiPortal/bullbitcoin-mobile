import 'package:swaps/order_swaps.dart' show OrderSwapRecord;
import 'package:receive/src/domain/usecases/poll_receive_wallet_usecase.dart';
import 'package:receive/src/domain/receive_wallet.dart';
import 'package:receive/src/presentation/bloc/receive_bloc.dart';
import 'package:receive/src/presentation/receive_navigation.dart';
import 'package:receive/src/ui/screens/receive_amount_screen.dart';
import 'package:receive/src/ui/screens/receive_payjoin_in_progress_screen.dart';
import 'package:receive/src/ui/screens/receive_payment_in_progress_screen.dart';
import 'package:receive/src/ui/screens/receive_payment_received_screen.dart';
import 'package:receive/src/ui/screens/receive_qr_screen.dart';
import 'package:receive/src/ui/screens/receive_scaffold.dart';
import 'package:transactions/routes.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ReceiveRoute {
  receiveBitcoin('/receive/bitcoin'),
  receiveLightning('/receive/lightning'),
  receiveLiquid('/receive/liquid'),
  lightningAmount('amount'),
  lightningQr('qr'),
  payjoinInProgress('payjoin'),
  lightningPaymentInProgress('in-progress'),
  lightningPaymentReceived('received');

  final String path;

  const ReceiveRoute(this.path);
}

/// A Boltz Lightning receive animates its payment as a transition; with the
/// payment animations preference off the flow opens the details instead.
bool _skipsLightningTransition(ReceiveState state) =>
    state.showPaymentAnimations == false &&
    state.orderSwap == null &&
    state.lightningSwap != null;

/// A Lightning payment waits for the preference before it picks a path.
bool _isPaymentInProgress(ReceiveState state) =>
    state.isPaymentInProgress &&
    (state.type != ReceiveType.lightning ||
        state.showPaymentAnimations != null);

bool _isPaymentReceived(ReceiveState state) =>
    state.isPaymentReceived &&
    !state.isPayjoinFlowOwningNavigation &&
    (state.type != ReceiveType.lightning ||
        state.showPaymentAnimations != null);

TransactionDetailsTarget? _lightningDetailsTarget(ReceiveState state) {
  final target = receiveDetailsTarget(state);
  if (target == null) return null;
  final walletId = target.walletId;
  return switch (target.kind) {
    ReceiveDetailsTargetKind.walletTransaction when walletId != null =>
      TransactionDetailsTarget.wallet(target.id, walletId: walletId),
    ReceiveDetailsTargetKind.swap when walletId != null =>
      TransactionDetailsTarget.swap(target.id, walletId: walletId),
    ReceiveDetailsTargetKind.orderSwap => TransactionDetailsTarget.orderSwap(
      target.id,
    ),
    ReceiveDetailsTargetKind.payjoin => TransactionDetailsTarget.payjoin(
      target.id,
    ),
    _ => null,
  };
}

/// Hosts the receive navigation listeners. Whether the Lightning details were
/// already opened (animations off) is navigation state of this shell, not of
/// the bloc.
class _ReceiveNavigationListeners extends StatefulWidget {
  final Widget child;

  const _ReceiveNavigationListeners({required this.child});

  @override
  State<_ReceiveNavigationListeners> createState() =>
      _ReceiveNavigationListenersState();
}

class _ReceiveNavigationListenersState
    extends State<_ReceiveNavigationListeners> {
  bool _lightningDetailsOpened = false;

  void _openLightningDetails(BuildContext context, ReceiveState state) {
    if (_lightningDetailsOpened) return;
    final details = _lightningDetailsTarget(state);
    if (details == null) return;
    _lightningDetailsOpened = true;
    TransactionsNavigation.goToDetails(
      context,
      details,
      returnHome: true,
      view: TransactionDetailsView.details,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ReceiveBloc, ReceiveState>(
          listenWhen: (previous, current) =>
              // makes sure it doesn't go from payment received to payment in progress again
              previous.isPaymentReceived != true &&
              ((!_isPaymentInProgress(previous) &&
                      _isPaymentInProgress(current)) ||
                  // A payjoin session can be first observed past
                  // `requested` (proposed, or already terminal) if the
                  // stream subscription raced a fast sender or a resume:
                  // any post-`started` status means the payjoin flow owns
                  // the UX from here (see isPayjoinFlowOwningNavigation) —
                  // navigate into the payjoin screen, which renders the
                  // right in-progress or terminal flavor.
                  (previous.isPayjoinFlowOwningNavigation != true &&
                      current.isPayjoinFlowOwningNavigation == true)),
          listener: (context, state) {
            final bloc = context.read<ReceiveBloc>();
            final type = state.type;

            // For a Payjoin or Lightning receive, show the payment in progress screen
            //  when the payjoin is requested or swap is claimable.
            // Since the payment in progress route is outside of the ShellRoute,
            // it uses the root navigator and so doesn't have the ReceiveBloc
            //  in the context. We need to pass it as an extra parameter.
            if (type == ReceiveType.bitcoin &&
                state.isPayjoinFlowOwningNavigation) {
              // Settled payjoin: the in-progress screen hands off itself
              // according to the preference once it is known.
              if (state.payjoin case final payjoin?
                  when payjoin.isCompleted &&
                      state.showPaymentAnimations == false) {
                TransactionsNavigation.goToDetails(
                  context,
                  TransactionDetailsTarget.payjoin(payjoin.id),
                  returnHome: true,
                  view: TransactionDetailsView.details,
                );
              } else {
                context.goNamed(
                  ReceiveRoute.payjoinInProgress.name,
                  extra: bloc,
                );
              }
            } else if (type == ReceiveType.lightning) {
              if (_skipsLightningTransition(state)) {
                _openLightningDetails(context, state);
                return;
              }
              context.goNamed(
                ReceiveRoute.lightningPaymentInProgress.name,
                extra: bloc,
              );
            }
          },
        ),
        BlocListener<ReceiveBloc, ReceiveState>(
          listenWhen: (previous, current) =>
              previous.hasTerminalLightningSwapFailure != true &&
              current.hasTerminalLightningSwapFailure,
          listener: (context, state) {
            // Details already opened for this payment (animations off):
            // a later swap failure must not pull the user back here.
            if (_lightningDetailsOpened) return;
            context.goNamed(ReceiveRoute.receiveLightning.name);
          },
        ),
        BlocListener<ReceiveBloc, ReceiveState>(
          listenWhen: (previous, current) =>
              !_isPaymentReceived(previous) && _isPaymentReceived(current),
          // The payjoin-in-progress screen (on the root navigator)
          // owns navigation once a payjoin session exists past
          // `started`; _isPaymentReceived keeps this generic listener from
          // whisking the user away before they can read the payjoin outcome.
          listener: (context, state) {
            final bloc = context.read<ReceiveBloc>();

            if (state.type == ReceiveType.lightning) {
              // The details are already open, or opened right here when
              // the payment went from pending to completed at once.
              if (_skipsLightningTransition(state)) {
                _openLightningDetails(context, state);
                return;
              }
              // For a Lightning receive, show the payment received screen
              //  when the payment is received.
              // Use pushReplacementNamed to only replace lightningPaymentInProgress
              // on the root navigator, without rebuilding the entire route stack.
              // Using goNamed would evict any routes pushed before the receive
              // flow (e.g. wallet detail) and cause layout errors mid-transition.
              context.pushReplacementNamed(
                ReceiveRoute.lightningPaymentReceived.name,
                extra: bloc,
              );
            }
          },
        ),
      ],
      child: widget.child,
    );
  }
}

class ReceiveRouter {
  static ShellRoute mount({
    required GlobalKey<NavigatorState> rootNavigatorKey,
    required ReceiveBloc Function(ReceiveWallet?) createBloc,
    required PollReceiveWalletUsecase poll,
    required void Function(BuildContext) openHome,
    required void Function(BuildContext) openPayjoinSettings,
    required ImageProvider successAnimation,
    Widget Function(OrderSwapRecord)? orderSwapUnderReview,
  }) => ShellRoute(
    navigatorKey: GlobalKey<NavigatorState>(),
    builder: (context, state, child) {
      // Pass a preselected wallet to the receive bloc if one is set in the URI
      //  of the incoming route
      final wallet = switch (state.extra) {
        final ReceiveWallet value => value,
        _ => null,
      };

      // Wrap the whole scaffold so its TopBar can host a bloc-aware payjoin toggle.
      // The scaffold selects only the displayed wallet and chain for its local polling timer.
      return BlocProvider<ReceiveBloc>(
        create: (_) => createBloc(wallet),
        child: ReceiveScaffold(
          poll: poll,
          openHome: openHome,
          wallet: wallet,
          child: _ReceiveNavigationListeners(child: child),
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
          final wallet = switch (state.extra) {
            final ReceiveWallet value => value,
            _ => null,
          };
          // Same guard as the lightning and liquid routes: this pageBuilder
          // re-runs when popping back from the child amount route, and an
          // unconditional restart wipes the confirmed amount and message the
          // user just entered there. Type mismatch only — comparing the
          // route-extra wallet would revert an in-flow dropdown switch on
          // pop-back (the extra still holds the wallet the flow was entered
          // with), and a fresh entry always has a null type anyway.
          if (bloc.state.type != ReceiveType.bitcoin) {
            bloc.add(ReceiveBitcoinStarted(wallet));
          }
          return NoTransitionPage(
            child: ReceiveQrPage(
              orderSwapUnderReview: orderSwapUnderReview,
              openPayjoinSettings: openPayjoinSettings,
            ),
          );
        },
        routes: [
          GoRoute(
            name: ReceiveRoute.payjoinInProgress.name,
            path: ReceiveRoute.payjoinInProgress.path,
            parentNavigatorKey: rootNavigatorKey,
            redirect: (_, state) => state.extra is ReceiveBloc
                ? null
                : ReceiveRoute.receiveBitcoin.path,
            builder: (context, state) {
              final bloc = state.extra;
              if (bloc is! ReceiveBloc) return const SizedBox.shrink();

              return BlocProvider.value(
                value: bloc,
                child: ReceivePayjoinInProgressScreen(openHome: openHome),
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
              openPayjoinSettings: openPayjoinSettings,
              onContinueNavigation: () => context.pushNamed(
                ReceiveRoute.lightningQr.name,
                extra: state.extra,
              ),
            ),
          );
        },
        routes: [
          GoRoute(
            name: ReceiveRoute.lightningQr.name,
            path: ReceiveRoute.lightningQr.path,
            pageBuilder: (context, state) => NoTransitionPage(
              child: ReceiveQrPage(
                orderSwapUnderReview: orderSwapUnderReview,
                openPayjoinSettings: openPayjoinSettings,
              ),
            ),
            routes: [
              GoRoute(
                name: ReceiveRoute.lightningAmount.name,
                path: ReceiveRoute.lightningAmount.path,
                pageBuilder: (context, state) => NoTransitionPage(
                  child: ReceiveAmountScreen(
                    openPayjoinSettings: openPayjoinSettings,
                  ),
                ),
              ),
              GoRoute(
                name: ReceiveRoute.lightningPaymentInProgress.name,
                path: ReceiveRoute.lightningPaymentInProgress.path,
                parentNavigatorKey: rootNavigatorKey,
                redirect: (_, state) => state.extra is ReceiveBloc
                    ? null
                    : ReceiveRoute.receiveLightning.path,
                builder: (context, state) {
                  final bloc = state.extra;
                  if (bloc is! ReceiveBloc) return const SizedBox.shrink();

                  return BlocProvider.value(
                    value: bloc,
                    child: ReceivePaymentInProgressScreen(openHome: openHome),
                  );
                },
              ),
              GoRoute(
                name: ReceiveRoute.lightningPaymentReceived.name,
                path: ReceiveRoute.lightningPaymentReceived.path,
                parentNavigatorKey: rootNavigatorKey,
                redirect: (_, state) => state.extra is ReceiveBloc
                    ? null
                    : ReceiveRoute.receiveLightning.path,
                builder: (context, state) {
                  final bloc = state.extra;
                  if (bloc is! ReceiveBloc) return const SizedBox.shrink();

                  return BlocProvider.value(
                    value: bloc,
                    child: ReceivePaymentReceivedScreen(
                      openHome: openHome,
                      successAnimation: successAnimation,
                    ),
                  );
                },
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

          return NoTransitionPage(
            child: ReceiveQrPage(
              orderSwapUnderReview: orderSwapUnderReview,
              openPayjoinSettings: openPayjoinSettings,
            ),
          );
        },
        routes: [],
      ),
    ],
  );
}
