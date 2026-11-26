import 'package:bull_exchange/src/buy/domain/buy_payjoin_window.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

/// The payjoin receiver a buy's payout can settle through.
typedef BuyPayjoinReceiver = ({String id, String bip21});

/// Opens a payjoin receiver on [walletId] for a payout of about [amountSat]
/// to [address]. Null when none can be opened: payjoin improves a purchase,
/// it never blocks one, and the order then pays the plain address.
Future<BuyPayjoinReceiver?> startBuyPayjoin(
  PayjoinReceiver receiver, {
  required String walletId,
  required BitcoinNetwork network,
  required String address,
  required int amountSat,
}) async {
  try {
    final result = await receiver.start(
      StartPayjoinReceiver(
        walletId: walletId,
        network: network,
        address: address,
        amount: Sats.fromInt(amountSat),
        isTrade: true,
        // The window the exchange negotiates a payout payjoin in. An idle
        // receiver freezes no coins, and a late payout still pays the plain
        // address the URI carries.
        expiresAt: clock.now().add(BuyPayjoinWindow.duration),
      ),
    );
    switch (result) {
      case Ok(:final value):
        log.fine('Buy Payjoin receiver attached: ref=${value.logRef}');
        return (id: value.id, bip21: value.pjUri);
      case Err(:final failure):
        log.warning(
          'Buy Payjoin unavailable; the order pays a plain address',
          error: '${failure.runtimeType}',
        );
        return null;
    }
  } catch (e) {
    // Only the type: foreign exception text can quote the payment request.
    log.warning(
      'Buy Payjoin unavailable; the order pays a plain address',
      error: '${e.runtimeType}',
    );
    return null;
  }
}

/// Drops a receiver no order uses (the create did not take effect).
Future<void> dropBuyPayjoin(PayjoinReceiver receiver, String id) async {
  if (await receiver.cancel(id) case Err()) {
    log.warning('Failed to drop an orphan Payjoin session');
  }
}

/// Cancels the payjoin receiver of an abandoned [order]: only one whose
/// payin never started. Cancelling a live one would drop the receiver while
/// the exchange pays it. `unknown` and `rejected` stay cancellable: the
/// session freezes the receiver's coins while it runs, and the exchange
/// settles the order through the original transaction either way.
Future<void> releaseBuyPayjoin(
  PayjoinSessions sessions,
  PayjoinReceiver receiver,
  BuyOrder order,
) async {
  final uri = order.bip21URI;
  if (uri == null) return;
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
  final List<PayjoinSession> payjoins;
  switch (await sessions.list(PayjoinSessionFilter(ongoingOnly: true))) {
    case Ok(:final value):
      payjoins = value;
    case Err(:final failure):
      log.warning(
        'Could not list Payjoin sessions; the abandoned one stays',
        error: failure.runtimeType,
      );
      return;
  }
  for (final payjoin in payjoins) {
    if (payjoin case PayjoinReceiverSession(:final id, :final pjUri)
        when _samePayjoinEndpoint(pjUri, uri)) {
      if (await receiver.cancel(id) case Err(:final failure)) {
        log.warning(
          'Failed to cancel the abandoned Payjoin receiver',
          error: failure.runtimeType,
        );
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
