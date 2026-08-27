import 'package:bb_mobile/core/primitives/payment_network.dart';

enum OrderSwapNetwork {
  bitcoin,
  liquid,
  lightning;

  String get apiName => name;

  PaymentNetwork get toPaymentNetwork => switch (this) {
    OrderSwapNetwork.bitcoin => PaymentNetwork.bitcoin,
    OrderSwapNetwork.liquid => PaymentNetwork.liquid,
    OrderSwapNetwork.lightning => PaymentNetwork.lightning,
  };
}
