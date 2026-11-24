import 'package:address_view/payment_destination.dart';
import 'package:exchange/exchange.dart';

extension BtcNetworkDestination on BtcNetwork {
  /// The destination the app's address parser accepts for a payout on this
  /// rail. On Lightning that is a Lightning address only.
  PaymentDestinationType get destinationType => switch (this) {
    BtcNetwork.bitcoin => PaymentDestinationType.bitcoin,
    BtcNetwork.liquid => PaymentDestinationType.liquid,
    BtcNetwork.lightning => PaymentDestinationType.lightningAddress,
  };
}
