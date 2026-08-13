import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/transactions/application/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class BroadcastPayjoinOriginalTxButton extends StatefulWidget {
  final PayjoinSession payjoin;

  const BroadcastPayjoinOriginalTxButton({required this.payjoin, super.key});

  @override
  State<BroadcastPayjoinOriginalTxButton> createState() =>
      _BroadcastPayjoinOriginalTxButtonState();
}

class _BroadcastPayjoinOriginalTxButtonState
    extends State<BroadcastPayjoinOriginalTxButton> {
  late bool _isVisible;
  var _requestId = 0;

  @override
  void initState() {
    super.initState();
    _isVisible = widget.payjoin.canManuallyBroadcastOriginal;
    _refreshVisibility();
  }

  @override
  void didUpdateWidget(BroadcastPayjoinOriginalTxButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payjoin != widget.payjoin) {
      _isVisible = widget.payjoin.canManuallyBroadcastOriginal;
      _refreshVisibility();
    }
  }

  Future<void> _refreshVisibility() async {
    final requestId = ++_requestId;
    final isVisible = await context
        .read<TransactionDetailsCubit>()
        .canBroadcastPayjoinOriginalTx();
    if (!mounted || requestId != _requestId) return;
    setState(() => _isVisible = isVisible);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final isBroadcastingPayjoinOriginalTx = context.select(
      (TransactionDetailsCubit bloc) =>
          bloc.state.isBroadcastingPayjoinOriginalTx,
    );
    final broadcastOriginalTransactionException = context.select(
      (TransactionDetailsCubit bloc) =>
          bloc.state.err is BroadcastOriginalTransactionException
          ? bloc.state.err! as BroadcastOriginalTransactionException
          : null,
    );
    final isSender = context.select(
      (TransactionDetailsCubit cubit) =>
          cubit.state.payjoin is PayjoinSenderSession,
    );
    return Column(
      children: [
        BBButton.big(
          label: isSender
              ? context.loc.transactionPayjoinSendWithout
              : context.loc.receivePaymentNormally,
          disabled: isBroadcastingPayjoinOriginalTx,
          onPressed: () async {
            SnackBarUtils.showSnackBar(
              context,
              context.loc.transactionPayjoinFallbackProcessing,
            );
            log.info('Broadcast regular transaction after payjoin abort');
            await context
                .read<TransactionDetailsCubit>()
                .broadcastPayjoinOriginalTx();
          },
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        const Gap(16),
        if (broadcastOriginalTransactionException != null) ...[
          Text(
            context.loc.oopsSomethingWentWrong,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.error,
            ),
            textAlign: .center,
          ),
          const Gap(16),
        ],
      ],
    );
  }
}
