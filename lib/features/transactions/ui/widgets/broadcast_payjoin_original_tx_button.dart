import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:clock/clock.dart';
import 'package:bb_mobile/features/transactions/presentation/transaction_failure_l10n.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSnackBar, Gap;

class BroadcastPayjoinOriginalTxButton extends StatefulWidget {
  final PayjoinSession payjoin;

  const BroadcastPayjoinOriginalTxButton({required this.payjoin, super.key});

  @override
  State<BroadcastPayjoinOriginalTxButton> createState() =>
      _BroadcastPayjoinOriginalTxButtonState();
}

class _BroadcastPayjoinOriginalTxButtonState
    extends State<BroadcastPayjoinOriginalTxButton> {
  static const _maxRetries = 3;

  late bool _isVisible;
  var _requestId = 0;
  var _retries = 0;
  Timer? _senderWaitTimer;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _isVisible = widget.payjoin.canManuallyBroadcastOriginalAt(clock.now());
    _scheduleSenderWait();
    _refreshVisibility();
  }

  @override
  void dispose() {
    _senderWaitTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleSenderWait() {
    _senderWaitTimer?.cancel();
    if (widget.payjoin case PayjoinReceiverSession(
      :final fallbackAvailableAt?,
    )) {
      final remaining = fallbackAvailableAt.difference(clock.now());
      if (widget.payjoin.isOngoing && remaining > Duration.zero) {
        _senderWaitTimer = Timer(remaining, _refreshVisibility);
      }
    }
  }

  @override
  void didUpdateWidget(BroadcastPayjoinOriginalTxButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_visibilityKey(oldWidget.payjoin) != _visibilityKey(widget.payjoin)) {
      _isVisible = widget.payjoin.canManuallyBroadcastOriginalAt(clock.now());
      _retryTimer?.cancel();
      _retries = 0;
      _scheduleSenderWait();
      _refreshVisibility();
    }
  }

  Object _visibilityKey(PayjoinSession payjoin) => (
    payjoin.id,
    payjoin.status,
    payjoin.txId,
    payjoin.originalTxId,
    payjoin.hasProposal,
    payjoin is PayjoinReceiverSession ? payjoin.fallbackAvailableAt : null,
    payjoin is PayjoinReceiverSession && payjoin.hasOriginalTransaction,
  );

  Future<void> _refreshVisibility() async {
    final requestId = ++_requestId;
    _retryTimer?.cancel();
    final result = await context
        .read<TransactionDetailsCubit>()
        .canBroadcastPayjoinOriginalTx();
    if (!mounted || requestId != _requestId) return;
    switch (result) {
      case Ok(value: true):
        _retries = 0;
        setState(() => _isVisible = true);
      case Ok(value: false):
        setState(() => _isVisible = false);
        // "Not yet" right at the deadline: the engine's wall clock can trail
        // the timer by a moment, so ask again shortly instead of waiting for
        // the session to change.
        if (_isAroundSenderDeadline) _scheduleRetry();
      case Err():
        // The check failed, not the eligibility: a passing network error
        // must not hide the fallback until the session changes again.
        _scheduleRetry();
    }
  }

  bool get _isAroundSenderDeadline {
    if (widget.payjoin case PayjoinReceiverSession(
      :final fallbackAvailableAt?,
    )) {
      final offset = clock.now().difference(fallbackAvailableAt).abs();
      return offset <= const Duration(seconds: 5);
    }
    return false;
  }

  void _scheduleRetry() {
    if (!widget.payjoin.isOngoing || _retries >= _maxRetries) return;
    _retries++;
    _retryTimer = Timer(
      Duration(seconds: 1 << (_retries - 1)),
      _refreshVisibility,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final isBroadcastingPayjoinOriginalTx = context.select(
      (TransactionDetailsCubit bloc) =>
          bloc.state.isBroadcastingPayjoinOriginalTx,
    );
    final broadcastFailure = context.select(
      (TransactionDetailsCubit bloc) => bloc.state.payjoinBroadcastFailure,
    );
    final isSender = context.select(
      (TransactionDetailsCubit cubit) =>
          cubit.state.payjoin is PayjoinSenderSession,
    );
    return Column(
      children: [
        BullButton.big(
          label: isSender
              ? context.loc.transactionPayjoinSendWithout
              : context.loc.receivePaymentNormally,
          disabled: isBroadcastingPayjoinOriginalTx,
          onPressed: () {
            log.info('Broadcast regular transaction after payjoin abort');
            final started = context
                .read<TransactionDetailsCubit>()
                .broadcastPayjoinOriginalTx();
            if (started) {
              BullSnackBar.show(
                context,
                message: context.loc.transactionPayjoinFallbackProcessing,
              );
            }
          },
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        const Gap(16),
        if (broadcastFailure != null) ...[
          Text(
            broadcastFailure.toTranslated(context),
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
