import 'package:bb_mobile/core/primitives/payment_network.dart';
import 'package:bull_swap/bull_swap.dart' show SwapNetwork;

extension SwapNetworkPaymentNetworkX on SwapNetwork {
  PaymentNetwork get toPaymentNetwork => switch (this) {
    SwapNetwork.bitcoin => PaymentNetwork.bitcoin,
    SwapNetwork.liquid => PaymentNetwork.liquid,
    SwapNetwork.lightning => PaymentNetwork.lightning,
  };
}
