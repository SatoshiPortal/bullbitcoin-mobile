import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_bloc.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_event.dart';
import 'package:bb_mobile/swap/bloc/watchtxs_state.dart';
import 'package:bb_mobile/wallet/bloc/event.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SwapAppListener extends StatelessWidget {
  const SwapAppListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<WatchTxsBloc, WatchTxsState>(
          listenWhen: (previous, current) => previous.txPaid != current.txPaid,
          listener: (context, state) {
            if (state.txPaid == null) return;

            // check page
            // if receive -> show full screen alert
            // if not -> show snackbar

            context.read<WatchTxsBloc>().add(ClearAlerts());
          },
        ),
        BlocListener<WatchTxsBloc, WatchTxsState>(
          listenWhen: (previous, current) => previous.syncWallet != current.syncWallet,
          listener: (context, state) {
            if (state.syncWallet == null) return;

            context
                .read<HomeCubit>()
                .state
                .getWalletBloc(
                  state.syncWallet!,
                )
                ?.add(SyncWallet());

            context.read<WatchTxsBloc>().add(ClearAlerts());
          },
        ),
      ],
      child: child,
    );
  }
}

class ReceiveSwapPaidSuccess extends StatelessWidget {
  const ReceiveSwapPaidSuccess({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class ReceiveAlertPopUp extends StatelessWidget {
  const ReceiveAlertPopUp({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
