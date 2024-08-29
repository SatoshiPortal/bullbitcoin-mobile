import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/home/bloc/home_state.dart';
import 'package:bb_mobile/routes.dart';
import 'package:bb_mobile/swap/receive.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_event.dart';
import 'package:bb_mobile/swap/watcher_bloc/watchtxs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:oktoast/oktoast.dart';

class SwapAppListener extends StatelessWidget {
  const SwapAppListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext ctx) {
    return MultiBlocListener(
      listeners: [
        BlocListener<HomeCubit, HomeState>(
          listenWhen: (previous, current) =>
              previous.loadingWallets != current.loadingWallets,
          listener: (context, state) {
            if (state.loadingWallets) return;

            context.read<WatchTxsBloc>().add(WatchWallets());
          },
        ),
        BlocListener<WatchTxsBloc, WatchTxsState>(
          listenWhen: (previous, current) =>
              previous.updatedSwapTx != current.updatedSwapTx &&
              current.updatedSwapTx != null &&
              current.updatedSwapTx!.showAlert(),
          listener: (context, state) {
            final route = context.read<NavName>().state;
            final isReceivePage = route == '/receive';
            final isSendPage = route == '/send';
            final isSwapReceivePage = route == '/swap-receive';
            final isOnchainSwapReceivePage = route == '/onchain-swap-receive';
            if (isReceivePage ||
                isSendPage ||
                isSwapReceivePage ||
                isOnchainSwapReceivePage) return;

            final swapTx = state.updatedSwapTx!;
            final isReverse = swapTx.isReverse();

            //TODO:DEBUG
            if (swapTx.isChainSwap()) return;

            final amt =
                isReverse ? swapTx.recievableAmount()! : swapTx.outAmount;
            final amtStr =
                context.read<CurrencyCubit>().state.getAmountInUnits(amt);
            final prefix = swapTx.actionPrefixStr();

            showToastWidget(
              position: ToastPosition.top,
              AlertUI(text: '$prefix $amtStr'),
              animationCurve: Curves.decelerate,
            );
          },
        ),
      ],
      child: _AppResumeRestartWatcher(child: child),
    );
  }
}

class _AppResumeRestartWatcher extends StatefulWidget {
  const _AppResumeRestartWatcher({required this.child});

  final Widget child;

  @override
  State<_AppResumeRestartWatcher> createState() =>
      __AppResumeRestartWatcherState();
}

class __AppResumeRestartWatcherState extends State<_AppResumeRestartWatcher>
    with WidgetsBindingObserver {
  bool inBackground = false;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final inBg = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;

    if (inBackground && !inBg) context.read<WatchTxsBloc>().add(WatchWallets());

    inBackground = inBg;
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
