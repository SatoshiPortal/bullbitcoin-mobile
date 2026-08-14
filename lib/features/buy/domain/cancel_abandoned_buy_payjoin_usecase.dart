import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

class CancelAbandonedBuyPayjoinUsecase {
  final PayjoinSessions _sessions;
  final PayjoinReceiver _receiver;

  const CancelAbandonedBuyPayjoinUsecase(this._sessions, this._receiver);

  Future<void> execute(BuyOrder? order) async {
    final uri = order?.bip21URI;
    if (order == null || uri == null) return;

    // Only an order whose pay-in never started is abandoned. Cancelling a live
    // one would drop the receiver session while the exchange is paying it.
    // `unknown` and `rejected` stay cancellable on purpose: the session freezes
    // the receiver's UTXOs for as long as it runs, and the exchange settles the
    // order through the original transaction either way.
    final isPayinLive = switch (order.payinStatus) {
      OrderPayinStatus.inProgress ||
      OrderPayinStatus.underReview ||
      OrderPayinStatus.awaitingConfirmation ||
      OrderPayinStatus.completed => true,
      OrderPayinStatus.notStarted ||
      OrderPayinStatus.awaitingPayment ||
      OrderPayinStatus.rejected ||
      OrderPayinStatus.unknown => false,
    };
    if (isPayinLive) return;

    final result = await _sessions.list(
      PayjoinSessionFilter(ongoingOnly: true),
    );
    final payjoins = switch (result) {
      Ok(:final value) => value,
      Err() => <PayjoinSession>[],
    };
    for (final payjoin in payjoins) {
      if (payjoin case PayjoinReceiverSession(
        :final id,
        :final pjUri,
      ) when _samePayjoinEndpoint(pjUri, uri)) {
        final cancelResult = await _receiver.cancel(id);
        if (cancelResult case Err()) {
          throw StateError('Failed to cancel Payjoin receiver');
        }
        return;
      }
    }
  }

  bool _samePayjoinEndpoint(String sessionUri, String orderUri) {
    final sessionEndpoint = Uri.tryParse(sessionUri)?.queryParameters['pj'];
    final orderEndpoint = Uri.tryParse(orderUri)?.queryParameters['pj'];
    return sessionEndpoint != null && sessionEndpoint == orderEndpoint;
  }
}
