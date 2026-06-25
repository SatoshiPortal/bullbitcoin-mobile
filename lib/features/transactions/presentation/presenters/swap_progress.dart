import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/features/transactions/presentation/presenters/view_models/transaction_detail_view_model.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';

/// Step-by-step progress of a swap, derived once and shared by the status row
/// summary, the expanded step view, and the progress steps indicator —
/// the single source of truth for "Step N of M".
class SwapProgress {
  const SwapProgress({
    required this.steps,
    required this.currentStep,
    required this.state,
  });

  final List<String> steps;

  /// 0-based index of the current step, or -1 when failed/expired.
  final int currentStep;
  final TxProgressState state;

  int get totalSteps => steps.length;
  bool get isFailedOrExpired => state == TxProgressState.failed;
}

SwapProgress swapProgressOf(Swap swap, AppLocalizations loc) {
  return SwapProgress(
    steps: _steps(swap, loc),
    currentStep: _currentStep(swap),
    state: _state(swap),
  );
}

TxProgressState _state(Swap swap) {
  if (swap.status == SwapStatus.failed || swap.status == SwapStatus.expired) {
    return TxProgressState.failed;
  }
  if (swap.status == SwapStatus.completed ||
      swap.status == SwapStatus.refunded) {
    return TxProgressState.completed;
  }
  return TxProgressState.inProgress;
}

List<String> _steps(Swap swap, AppLocalizations loc) {
  if (swap is LnReceiveSwap) {
    return [
      loc.transactionSwapProgressInitiated,
      loc.transactionSwapProgressPaymentMade,
      loc.transactionSwapProgressFundsClaimed,
    ];
  } else if (swap is LnSendSwap) {
    return [
      loc.transactionSwapProgressInitiated,
      loc.transactionSwapProgressBroadcasted,
      loc.transactionSwapProgressInvoicePaid,
    ];
  } else if (swap is ChainSwap) {
    return [
      loc.transactionSwapProgressInitiated,
      loc.transactionSwapProgressConfirmed,
      loc.transactionSwapProgressClaim,
      loc.transactionSwapProgressCompleted,
    ];
  }
  return [
    loc.transactionSwapProgressInitiated,
    loc.transactionSwapProgressInProgress,
    loc.transactionSwapProgressCompleted,
  ];
}

int _currentStep(Swap swap) {
  if (swap.status == SwapStatus.failed || swap.status == SwapStatus.expired) {
    return -1;
  }
  return switch (swap.status) {
    SwapStatus.pending => 0,
    SwapStatus.paid => 1,
    SwapStatus.claimable => swap is ChainSwap ? 2 : 1,
    SwapStatus.refundable => swap is ChainSwap ? 2 : 1,
    SwapStatus.canCoop => swap is ChainSwap ? 2 : 1,
    SwapStatus.completed || SwapStatus.refunded => swap is ChainSwap ? 3 : 2,
    SwapStatus.failed || SwapStatus.expired => 0,
  };
}
