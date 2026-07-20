import 'package:bb_mobile/features/bullnym/data/bullnym_get_paid_transaction_model.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_get_paid_transaction.dart';

extension BullnymGetPaidTransactionModelMapper
    on BullnymGetPaidTransactionModel {
  BullnymGetPaidTransaction toDomain() {
    return BullnymGetPaidTransaction(
      transactionId: transactionId,
      source: _source(source),
      invoiceId: invoiceId,
      amountSat: amountSat,
      receivedAtUnix: receivedAtUnix,
      rail: _rail(rail),
      settlementState: _settlementState(settlementState),
      late: late,
      comment: comment,
      settlement: settlement,
    );
  }
}

BullnymGetPaidTransactionSource _source(String value) => switch (value) {
  'lightning_address' => BullnymGetPaidTransactionSource.lightningAddress,
  'invoice' => BullnymGetPaidTransactionSource.invoice,
  'payment_page' => BullnymGetPaidTransactionSource.paymentPage,
  'point_of_sale' => BullnymGetPaidTransactionSource.pointOfSale,
  _ => throw FormatException('Unknown Get Paid transaction source'),
};

BullnymGetPaidTransactionRail _rail(String value) => switch (value) {
  'lightning' => BullnymGetPaidTransactionRail.lightning,
  'liquid' => BullnymGetPaidTransactionRail.liquid,
  'bitcoin' => BullnymGetPaidTransactionRail.bitcoin,
  _ => throw FormatException('Unknown Get Paid transaction rail'),
};

BullnymGetPaidSettlementState _settlementState(String value) => switch (value) {
  'pending' => BullnymGetPaidSettlementState.pending,
  'settled' => BullnymGetPaidSettlementState.settled,
  'problem' => BullnymGetPaidSettlementState.problem,
  _ => throw FormatException('Unknown Get Paid settlement state'),
};
