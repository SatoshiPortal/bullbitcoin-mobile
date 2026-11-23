import 'package:primitives/primitives.dart' show PaymentNetwork;

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
