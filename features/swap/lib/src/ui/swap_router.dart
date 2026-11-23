import 'package:flutter/widgets.dart';
import 'package:swaps/swaps.dart' show ChainSwap;
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:swap_feature/src/presentation/internal_ark_transfer_cubit.dart';
import 'package:swap_feature/src/ui/pages/swap_confirm_page.dart';
import 'package:swap_feature/src/ui/pages/swap_in_progress_page.dart';
import 'package:swap_feature/src/ui/pages/internal_transfer_page.dart';
import 'package:transactions/routes.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum TransferRoute {
  swap('/swap'),
  confirmSwap('/swap/confirm'),
  inProgressSwap('/swap/in-progress');

  final String path;

  const TransferRoute(this.path);
}

class SwapRouter {
  static GoRoute route({
    required TransferBloc Function() createTransfer,
    required InternalArkTransferCubit Function() createArk,
  }) => GoRoute(
    name: TransferRoute.swap.name,
    path: TransferRoute.swap.path,
    builder: (context, state) => BlocProvider(
      create: (_) => createTransfer()..add(const TransferStarted()),
      child: BlocListener<TransferBloc, TransferState>(
        listenWhen: (previous, current) =>
            previous.signedPsbt.isEmpty &&
            current.signedPsbt.isNotEmpty &&
            ((current.swap != null && current.swap is ChainSwap) ||
                current.isSameChainTransfer),
        listener: (context, state) async {
          final bloc = context.read<TransferBloc>();
          await context.pushNamed(TransferRoute.confirmSwap.name, extra: bloc);
          if (!bloc.isClosed && bloc.state.txId.isEmpty) {
            bloc.add(const TransferEvent.amountEditingResumed());
          }
        },
        child: InternalTransferPage(createArkCubit: createArk),
      ),
    ),
    routes: [
      GoRoute(
        name: TransferRoute.confirmSwap.name,
        path: TransferRoute.confirmSwap.path,
        builder: (context, state) {
          final bloc = state.extra;
          if (bloc is! TransferBloc) return const SizedBox.shrink();

          return BlocProvider.value(
            value: bloc,
            child: BlocListener<TransferBloc, TransferState>(
              listenWhen: (previous, current) =>
                  previous.txId.isEmpty && current.txId.isNotEmpty,
              listener: (context, state) {
                final orderSwap = state.orderSwap;
                if (orderSwap != null) {
                  TransactionsNavigation.goToDetails(
                    context,
                    TransactionDetailsTarget.orderSwap(orderSwap.localId),
                    returnHome: true,
                  );
                } else {
                  context.goNamed(
                    TransferRoute.inProgressSwap.name,
                    extra: context.read<TransferBloc>(),
                  );
                }
              },
              child: const SwapConfirmPage(),
            ),
          );
        },
      ),
      GoRoute(
        name: TransferRoute.inProgressSwap.name,
        path: TransferRoute.inProgressSwap.path,
        builder: (context, state) {
          final bloc = state.extra;
          if (bloc is! TransferBloc) return const SizedBox.shrink();

          return BlocProvider.value(
            value: bloc,
            child: const SwapInProgressPage(),
          );
        },
      ),
    ],
  );
}
