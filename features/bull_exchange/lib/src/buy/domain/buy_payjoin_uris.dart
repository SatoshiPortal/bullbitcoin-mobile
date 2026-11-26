import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:exchange/exchange.dart';

/// The payjoin URI each buy create attached, by order and by request: some
/// exchange replies don't echo it, and the done page and the release read
/// it. One per flow, shared by the buy order use cases.
final class BuyPayjoinUris {
  final _byOrder = <String, String>{};
  final _byRequest = <BuyRequest, String>{};

  /// The create of [orderId] attached [bip21].
  void attachToOrder(String orderId, String bip21) => _byOrder[orderId] = bip21;

  /// The create of [request] attached [bip21] but its outcome is unknown:
  /// the order may exist and pay through this receiver.
  void attachToRequest(BuyRequest request, String bip21) =>
      _byRequest[request] = bip21;

  /// [orderId] is the order an unknown create of [request] made: it takes
  /// the URI that create attached.
  void adopt(BuyRequest request, String orderId) {
    if (_byRequest[request] case final bip21?) _byOrder[orderId] = bip21;
  }

  /// [order] with the URI its create attached, when the reply didn't echo
  /// it.
  BuyOrder withBip21(BuyOrder order) {
    final bip21 = _byOrder[order.orderId];
    return bip21 != null && order.bip21URI == null
        ? order.copyWith(bip21URI: bip21)
        : order;
  }
}
