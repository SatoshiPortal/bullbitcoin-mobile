import 'package:bb_mobile/features/swap/domain/swap_failure.dart';

enum OrderSwapPollingKind { active, idle, rateLimited }

/// The last completed polling state, retained across dropped or failed requests.
final class OrderSwapPolling {
  final OrderSwapPollingKind kind;
  final Duration? retryAfter;

  const OrderSwapPolling.active()
    : kind = OrderSwapPollingKind.active,
      retryAfter = null;
  const OrderSwapPolling.idle()
    : kind = OrderSwapPollingKind.idle,
      retryAfter = null;
  const OrderSwapPolling.rateLimited({this.retryAfter})
    : kind = OrderSwapPollingKind.rateLimited;
}

final class OrderSwapPollingAttempt {
  final OrderSwapPolling? lastOutcome;
  final SwapFailure? failure;

  const OrderSwapPollingAttempt({this.lastOutcome, this.failure});
}
