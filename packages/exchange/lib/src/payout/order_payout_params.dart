import 'package:meta/meta.dart';

import '../domain/entities/sepa_payment_processor.dart';
import '../recipients/domain/entities/interac_security_details.dart';

/// What an order that pays a recipient sends about the payout, from the
/// recipient's rail and its met requirements (composition §3.1
/// `orderParams`). One mapping for sell, pay and withdraw (D10).
@immutable
final class OrderPayoutParams {
  final String recipientId;
  final SepaPaymentProcessor? paymentProcessor;

  /// Sent as `paymentProcessorData` for an Interac payout.
  final InteracSecurityAnswer? interacAnswer;

  const OrderPayoutParams({
    required this.recipientId,
    this.paymentProcessor,
    this.interacAnswer,
  });

  @override
  bool operator ==(Object other) =>
      other is OrderPayoutParams &&
      other.recipientId == recipientId &&
      other.paymentProcessor == paymentProcessor &&
      other.interacAnswer == interacAnswer;

  @override
  int get hashCode => Object.hash(recipientId, paymentProcessor, interacAnswer);

  @override
  String toString() =>
      'OrderPayoutParams($recipientId, $paymentProcessor, '
      'interac: ${interacAnswer != null})';
}
