import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bull_sdk/bwk.dart' as bwk;

/// Maps the bwk FFI `SpPaymentView` into the domain [SpPayment].
abstract final class SpPaymentMapper {
  static SpPayment toDomain(bwk.SpPaymentView view) => SpPayment(
    txid: view.txid,
    direction: switch (view.direction) {
      bwk.SpPaymentDirection.receive => SpPaymentDirection.receive,
      bwk.SpPaymentDirection.send => SpPaymentDirection.send,
      bwk.SpPaymentDirection.selfSend => SpPaymentDirection.selfSend,
    },
    amountSat: view.amountSat,
    feeSat: view.feeSat,
    height: view.height,
    timestamp: view.timestamp,
    label: view.label,
  );
}
