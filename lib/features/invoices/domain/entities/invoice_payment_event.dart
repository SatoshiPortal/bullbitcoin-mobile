import 'package:bb_mobile/features/invoices/domain/primitives/payment_method.dart';

/// The merchant-facing settlement posture of an invoice. This is deliberately
/// separate from the invoice lifecycle: a lifecycle value of `paid` can still
/// be provisional while chain evidence is awaiting finality.
enum InvoiceSettlementState { none, pending, settled, problem }

enum InvoicePaymentEventState { pending, confirming, settled, problem }

enum InvoicePaymentProblem { evicted, reorged, conflicted, replaced, unknown }

/// One durable payment observation attributed to the original invoice.
class InvoicePaymentEvent {
  final PaymentMethod rail;
  final int amountSat;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final InvoicePaymentEventState state;
  final int confirmations;
  final String? transactionId;
  final int? outputIndex;
  final bool isLate;
  final InvoicePaymentProblem? problem;

  InvoicePaymentEvent({
    required this.rail,
    required this.amountSat,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.state,
    required this.confirmations,
    this.transactionId,
    this.outputIndex,
    required this.isLate,
    this.problem,
  }) {
    if (amountSat < 0 || confirmations < 0) {
      throw ArgumentError(
        'Payment amounts and confirmations cannot be negative',
      );
    }
    if (outputIndex != null && outputIndex! < 0) {
      throw ArgumentError('Payment output index cannot be negative');
    }
    if (state == InvoicePaymentEventState.problem && problem == null) {
      throw ArgumentError('A problem payment event requires a problem reason');
    }
    if (state != InvoicePaymentEventState.problem && problem != null) {
      throw ArgumentError(
        'Only a problem payment event may carry a problem reason',
      );
    }
  }

  bool get isProvisional =>
      state == InvoicePaymentEventState.pending ||
      state == InvoicePaymentEventState.confirming;
}

InvoiceSettlementState invoiceSettlementStateFromWire({
  required String settlementStatus,
  required String? presentationStatus,
  required bool hasPaymentEvidence,
}) {
  final settlement = _normalize(settlementStatus);
  final presentation = _normalize(presentationStatus);

  if (_isProblem(settlement) || _isProblem(presentation)) {
    return InvoiceSettlementState.problem;
  }
  if (_isSettled(settlement)) {
    return InvoiceSettlementState.settled;
  }
  if (hasPaymentEvidence && _isPending(settlement)) {
    return InvoiceSettlementState.pending;
  }
  if (_isSettled(presentation)) return InvoiceSettlementState.settled;
  if (_isPending(presentation)) return InvoiceSettlementState.pending;
  // Unknown evidence-bearing states must never be presented as final.
  return hasPaymentEvidence
      ? InvoiceSettlementState.pending
      : InvoiceSettlementState.none;
}

InvoicePaymentProblem? invoicePaymentProblemFromWire(String state) {
  final normalized = _normalize(state);
  if (normalized.contains('evict') || normalized.contains('drop')) {
    return InvoicePaymentProblem.evicted;
  }
  if (normalized.contains('reorg')) return InvoicePaymentProblem.reorged;
  if (normalized.contains('orphan')) return InvoicePaymentProblem.reorged;
  if (normalized.contains('conflict') || normalized.contains('double_spend')) {
    return InvoicePaymentProblem.conflicted;
  }
  if (normalized.contains('replac')) return InvoicePaymentProblem.replaced;
  if (_isProblem(normalized)) return InvoicePaymentProblem.unknown;
  return null;
}

InvoicePaymentEventState invoicePaymentEventStateFromWire({
  required String state,
  required int confirmations,
  required InvoiceSettlementState invoiceSettlement,
}) {
  if (invoicePaymentProblemFromWire(state) != null) {
    return InvoicePaymentEventState.problem;
  }
  if (invoiceSettlement == InvoiceSettlementState.settled ||
      _isSettled(_normalize(state))) {
    return InvoicePaymentEventState.settled;
  }
  if (confirmations > 0 || _normalize(state).contains('confirm')) {
    return InvoicePaymentEventState.confirming;
  }
  return InvoicePaymentEventState.pending;
}

bool invoicePresentationMarksLate(String? presentationStatus) =>
    _normalize(presentationStatus).contains('late');

String _normalize(String? value) =>
    value?.trim().toLowerCase().replaceAll('-', '_') ?? '';

bool _isSettled(String value) =>
    value == 'settled' ||
    value == 'final' ||
    value == 'finalized' ||
    value == 'payment_settled';

bool _isPending(String value) =>
    value == 'pending' ||
    value == 'payment_detected' ||
    value == 'payment_received' ||
    value == 'settlement_pending' ||
    value == 'confirming' ||
    value == 'broadcast' ||
    value == 'mempool' ||
    value == 'being_paid';

bool _isProblem(String value) =>
    value.contains('problem') ||
    value.contains('failed') ||
    value.contains('evict') ||
    value.contains('drop') ||
    value.contains('reorg') ||
    value.contains('orphan') ||
    value.contains('conflict') ||
    value.contains('double_spend') ||
    value.contains('replac') ||
    value.contains('invalid');
